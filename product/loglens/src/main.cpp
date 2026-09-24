#include <charconv>
#include <csignal>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <limits>
#include <memory>
#include <string>
#include <string_view>

#include "loglens/aggregator.hpp"
#include "loglens/input.hpp"
#include "loglens/parser.hpp"
#include "loglens/result.hpp"

namespace {

constexpr std::string_view kVersion = "1.2.0";
constexpr std::size_t kDefaultMaxLineBytes = 1024 * 1024;
constexpr std::size_t kDefaultMaxServices = 10'000;

struct Options {
  std::string input;
  std::size_t max_line_bytes{kDefaultMaxLineBytes};
  std::size_t max_services{kDefaultMaxServices};
  bool strict{};
};

auto usage(std::ostream &output) -> void {
  output << "Usage: loglens --input FILE [OPTIONS]\n"
            "       loglens --help | --version\n\n"
            "FILE may be '-' for standard input.\n"
            "Options:\n"
            "  --strict              Fail on the first malformed line\n"
            "  --max-line-bytes N    Maximum bytes per line (default 1048576)\n"
            "  --max-services N      Maximum unique services (default 10000)\n";
}

auto positive_size(std::string_view value)
    -> loglens::Result<std::size_t, std::string_view> {
  std::uint64_t parsed{};
  const auto result =
      std::from_chars(value.data(), value.data() + value.size(), parsed);
  if (value.empty() || result.ec != std::errc{} ||
      result.ptr != value.data() + value.size() || parsed == 0 ||
      parsed > std::numeric_limits<std::size_t>::max()) {
    return loglens::unexpected<std::string_view>(
        "limit must be a positive integer");
  }
  return static_cast<std::size_t>(parsed);
}

auto parse_options(int argc, char **argv)
    -> loglens::Result<Options, std::string_view> {
  Options options;
  bool saw_input = false;
  bool saw_strict = false;
  bool saw_max_line = false;
  bool saw_max_services = false;
  for (int index = 1; index < argc; ++index) {
    const std::string_view argument = argv[index];
    if (argument == "--help") {
      if (argc != 2)
        return loglens::unexpected<std::string_view>(
            "--help cannot be combined with other options");
      usage(std::cout);
      std::exit(0);
    }
    if (argument == "--version") {
      if (argc != 2)
        return loglens::unexpected<std::string_view>(
            "--version cannot be combined with other options");
      std::cout << "loglens " << kVersion << '\n';
      std::exit(0);
    }
    if (argument == "--strict") {
      if (saw_strict)
        return loglens::unexpected<std::string_view>("duplicate --strict");
      saw_strict = true;
      options.strict = true;
      continue;
    }

    const bool takes_value = argument == "--input" ||
                             argument == "--max-line-bytes" ||
                             argument == "--max-services";
    if (!takes_value || index + 1 >= argc) {
      return loglens::unexpected<std::string_view>(
          "unknown or incomplete argument");
    }
    const std::string_view value = argv[++index];
    if (argument == "--input") {
      if (saw_input)
        return loglens::unexpected<std::string_view>("duplicate --input");
      saw_input = true;
      options.input = value;
    } else if (argument == "--max-line-bytes") {
      if (saw_max_line)
        return loglens::unexpected<std::string_view>(
            "duplicate --max-line-bytes");
      saw_max_line = true;
      const auto parsed = positive_size(value);
      if (!parsed)
        return loglens::unexpected(parsed.error());
      options.max_line_bytes = *parsed;
    } else {
      if (saw_max_services)
        return loglens::unexpected<std::string_view>(
            "duplicate --max-services");
      saw_max_services = true;
      const auto parsed = positive_size(value);
      if (!parsed)
        return loglens::unexpected(parsed.error());
      options.max_services = *parsed;
    }
  }
  if (!saw_input || options.input.empty()) {
    return loglens::unexpected<std::string_view>("--input is required");
  }
  return options;
}

auto run(int argc, char **argv) -> int {
  const auto options = parse_options(argc, argv);
  if (!options) {
    std::cerr << "loglens: " << options.error() << '\n';
    usage(std::cerr);
    return 2;
  }

  std::ifstream file;
  std::istream *input = &std::cin;
  if (options->input != "-") {
    file.open(options->input, std::ios::binary);
    if (!file) {
      std::cerr << "loglens: cannot open input: " << options->input << '\n';
      return 3;
    }
    input = &file;
  }

  loglens::Aggregator aggregator(options->max_services);
  std::string line;
  std::uint64_t line_number = 0;
  for (;;) {
    const auto result =
        loglens::read_bounded_line(*input, line, options->max_line_bytes);
    if (result == loglens::ReadLineResult::end)
      break;
    ++line_number;
    if (result == loglens::ReadLineResult::error) {
      std::cerr << "loglens: read error\n";
      return 3;
    }
    if (result == loglens::ReadLineResult::too_long) {
      std::cerr << "loglens: line " << line_number
                << ": exceeds --max-line-bytes\n";
      return 5;
    }

    const auto parsed = loglens::parse_line(line);
    if (parsed) {
      if (aggregator.add(*parsed) ==
          loglens::Aggregator::AddResult::service_limit_exceeded) {
        std::cerr << "loglens: line " << line_number
                  << ": exceeds --max-services\n";
        return 5;
      }
      continue;
    }

    aggregator.add_malformed();
    std::cerr << "loglens: line " << line_number << ": "
              << parsed.error().message << '\n';
    if (options->strict)
      return 4;
  }

  std::cout << loglens::render_json(aggregator);
  std::cout.flush();
  if (!std::cout) {
    std::cerr << "loglens: write error\n";
    return 3;
  }
  return 0;
}

} // namespace

auto main(int argc, char **argv) -> int {
#ifdef SIGPIPE
  // Convert a closed output pipe into the documented exit code 3.
  std::signal(SIGPIPE, SIG_IGN);
#endif
  try {
    return run(argc, argv);
  } catch (const std::bad_alloc &) {
    std::cerr << "loglens: memory allocation failed\n";
    return 5;
  }
}
