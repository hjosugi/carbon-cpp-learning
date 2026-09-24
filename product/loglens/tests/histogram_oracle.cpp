// C++ side of the C++/Carbon histogram differential test (issues #21, #22).
//
// It writes vector files and evaluates them with LatencyHistogram, so that the
// Carbon port in carbon_experiments/histogram.carbon can be compared with the
// C++ implementation byte for byte.
//
// Vector file format (v1). One vector per line, every line ends with '\n':
//
//   # text             comment, ignored
//   L <latency_ms>     evaluated as "L <latency_ms> <bucket> <bucket_upper>"
//   B <bucket>         evaluated as "B <bucket> <bucket_upper>"
//
// Numbers are decimal values in 0..UINT32_MAX (leading zeros are accepted,
// output is canonical). Evaluation stops with exit code 2 at the first
// malformed line; the lines before it have already been written.
//
// Usage:
//   histogram_oracle boundary   write every bucket-edge vector
//   histogram_oracle eval       evaluate a vector file from stdin

#include <charconv>
#include <cstdint>
#include <iostream>
#include <limits>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>

#include "loglens/aggregator.hpp"

namespace {

using loglens::LatencyHistogram;

constexpr std::uint32_t kU32Max = std::numeric_limits<std::uint32_t>::max();

// Both edges of every bucket, independent of LatencyHistogram: 0 is bucket 0,
// 2^(n-1) and 2^n-1 are the edges of bucket n. Then bucket_upper for buckets
// 0..33 and two far out-of-range buckets, which must saturate.
auto write_boundary_vectors(std::ostream& out) -> void {
  out << "# loglens histogram vectors v1\n"
      << "# boundary: both edges of buckets 0..32, bucket_upper 0..33/64/max\n"
      << "L 0\n";
  for (std::uint32_t bucket = 1; bucket <= 32; ++bucket) {
    const auto lower = std::uint64_t{1} << (bucket - 1);
    const auto upper = (std::uint64_t{1} << bucket) - 1;
    out << "L " << lower << '\n';
    if (upper != lower) out << "L " << upper << '\n';
  }
  for (std::uint32_t bucket = 0; bucket <= 33; ++bucket) {
    out << "B " << bucket << '\n';
  }
  out << "B 64\n"
      << "B " << kU32Max << '\n';
}

// A decimal u32 that fills the whole view. from_chars rejects signs and
// whitespace for unsigned types and reports out-of-range values.
auto parse_u32(std::string_view text) -> std::optional<std::uint32_t> {
  if (text.empty()) return std::nullopt;
  std::uint32_t value{};
  const auto* const end = text.data() + text.size();
  const auto [ptr, error] = std::from_chars(text.data(), end, value);
  if (error != std::errc{} || ptr != end) return std::nullopt;
  return value;
}

auto evaluate(std::istream& in, std::ostream& out) -> int {
  std::string line;
  std::uint64_t line_number = 0;
  while (std::getline(in, line)) {
    ++line_number;
    // getline sets eofbit when the last line has no '\n'.
    const bool terminated = !in.eof();
    if (terminated && line.starts_with('#')) continue;
    const std::string_view view(line);
    const auto value = view.size() > 2 ? parse_u32(view.substr(2))
                                       : std::optional<std::uint32_t>{};
    if (!terminated || !value || view[1] != ' ' ||
        (view[0] != 'L' && view[0] != 'B')) {
      out.flush();
      std::cerr << "histogram_oracle: line " << line_number
                << ": malformed vector\n";
      return 2;
    }
    if (view[0] == 'L') {
      const auto bucket = LatencyHistogram::bucket_for(*value);
      out << "L " << *value << ' ' << bucket << ' '
          << LatencyHistogram::bucket_upper(bucket) << '\n';
    } else {
      out << "B " << *value << ' ' << LatencyHistogram::bucket_upper(*value)
          << '\n';
    }
  }
  return 0;
}

auto usage() -> int {
  std::cerr << "usage: histogram_oracle boundary\n"
               "       histogram_oracle eval < vectors\n";
  return 64;
}

}  // namespace

auto main(int argc, char** argv) -> int {
  std::ios::sync_with_stdio(false);
  if (argc != 2) return usage();
  const std::string_view command(argv[1]);
  if (command == "boundary") {
    write_boundary_vectors(std::cout);
    return 0;
  }
  if (command == "eval") return evaluate(std::cin, std::cout);
  return usage();
}
