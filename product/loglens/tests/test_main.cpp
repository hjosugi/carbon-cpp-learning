#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#include "loglens/aggregator.hpp"
#include "loglens/c_api.h"
#include "loglens/input.hpp"
#include "loglens/parser.hpp"

namespace {

auto check(bool condition, const char* expression, int line) -> void {
  if (!condition) {
    std::cerr << "FAIL line " << line << ": " << expression << '\n';
    std::exit(1);
  }
}

#define CHECK(expression) check((expression), #expression, __LINE__)

auto test_parser_accepts_valid_lines() -> void {
  constexpr std::array inputs{
      "2026-07-12T01:00:00Z INFO payments-api 17 200",
      "2024-02-29T23:59:59.123456Z TRACE worker_1 0 599",
      "0000-01-01T00:00:00Z FATAL a.b 4294967295 100",
  };
  for (const std::string_view input : inputs) {
    CHECK(loglens::parse_line(input).has_value());
  }

  const auto result = loglens::parse_line(inputs.front());
  CHECK(result->service == "payments-api");
  CHECK(result->latency_ms == 17);
  CHECK(result->status == 200);
}

auto test_parser_error_table() -> void {
  struct Case {
    std::string_view input;
    loglens::ParseErrorCode code;
  };
  constexpr std::array cases{
      Case{"too few fields", loglens::ParseErrorCode::wrong_field_count},
      Case{"2026-07-12T01:00:00Z INFO api 17 200 extra",
           loglens::ParseErrorCode::wrong_field_count},
      Case{"2026-02-29T01:00:00Z INFO api 17 200",
           loglens::ParseErrorCode::invalid_timestamp},
      Case{"2024-04-31T01:00:00Z INFO api 17 200",
           loglens::ParseErrorCode::invalid_timestamp},
      Case{"2024-01-01T24:00:00Z INFO api 17 200",
           loglens::ParseErrorCode::invalid_timestamp},
      Case{"2024-01-01T23:59:60Z INFO api 17 200",
           loglens::ParseErrorCode::invalid_timestamp},
      Case{"2024-01-01T23:59:59.Z INFO api 17 200",
           loglens::ParseErrorCode::invalid_timestamp},
      Case{"2026-07-12T01:00:00Z NOTICE api 17 200",
           loglens::ParseErrorCode::invalid_level},
      Case{"2026-07-12T01:00:00Z INFO bad/service 17 200",
           loglens::ParseErrorCode::invalid_service},
      Case{"2026-07-12T01:00:00Z INFO api nope 200",
           loglens::ParseErrorCode::invalid_latency},
      Case{"2026-07-12T01:00:00Z INFO api 4294967296 200",
           loglens::ParseErrorCode::invalid_latency},
      Case{"2026-07-12T01:00:00Z INFO api 17 99",
           loglens::ParseErrorCode::invalid_status},
      Case{"2026-07-12T01:00:00Z INFO api 17 600",
           loglens::ParseErrorCode::invalid_status},
  };

  for (const auto& test : cases) {
    const auto result = loglens::parse_line(test.input);
    CHECK(!result);
    CHECK(result.error().code == test.code);
  }
}

auto test_all_histogram_boundaries() -> void {
  for (std::size_t bucket = 0;
       bucket < loglens::LatencyHistogram::kBucketCount; ++bucket) {
    const std::uint64_t expected_upper =
        bucket == 0
            ? 0
            : bucket >= 32 ? std::numeric_limits<std::uint32_t>::max()
                           : (std::uint64_t{1} << bucket) - 1;
    CHECK(loglens::LatencyHistogram::bucket_upper(bucket) == expected_upper);
    CHECK(loglens_bucket_upper(static_cast<std::uint32_t>(bucket)) ==
          expected_upper);

    const std::uint32_t lower =
        bucket == 0 ? 0 : std::uint32_t{1} << (bucket - 1);
    const auto upper = static_cast<std::uint32_t>(expected_upper);
    for (const std::uint32_t value : {lower, upper}) {
      CHECK(loglens::LatencyHistogram::bucket_for(value) == bucket);
      loglens::LatencyHistogram histogram;
      histogram.add(value);
      CHECK(histogram.count() == 1);
      CHECK(histogram.percentile_upper(1.0) == expected_upper);
    }
  }

  // Out-of-range buckets saturate like bucket 32; they never shift by >= 64.
  constexpr auto u32_max = std::numeric_limits<std::uint32_t>::max();
  for (const std::uint32_t bucket : {33U, 64U, u32_max}) {
    CHECK(loglens::LatencyHistogram::bucket_upper(bucket) == u32_max);
    CHECK(loglens_bucket_upper(bucket) == u32_max);
  }
}

auto exact_nearest_rank(std::vector<std::uint32_t> values, double quantile)
    -> std::uint32_t {
  std::ranges::sort(values);
  const auto rank = std::max<std::size_t>(
      static_cast<std::size_t>(
          std::ceil(std::clamp(quantile, 0.0, 1.0) *
                    static_cast<double>(values.size()))),
      1);
  return values[rank - 1];
}

auto test_percentile_error_bound() -> void {
  const std::vector<std::uint32_t> values{
      0,   1,   2,   3,   4,   7,   8,   15,  16,  31,
      32,  63,  64,  127, 128, 255, 256, 511, 512, 1000,
  };
  loglens::LatencyHistogram histogram;
  for (const auto value : values) histogram.add(value);

  for (const double quantile : {0.50, 0.95, 0.99}) {
    const auto exact = exact_nearest_rank(values, quantile);
    const auto approximate = histogram.percentile_upper(quantile);
    CHECK(approximate >= exact);
    CHECK(exact == 0 ? approximate == 0 : approximate < 2ULL * exact);
  }
}

auto test_latency_sum_saturation() -> void {
  loglens::ServiceStats stats;
  stats.latency_sum = std::numeric_limits<std::uint64_t>::max() - 5;
  stats.add_latency(4);
  CHECK(stats.latency_sum == std::numeric_limits<std::uint64_t>::max() - 1);
  CHECK(!stats.latency_sum_saturated);
  stats.add_latency(10);
  CHECK(stats.latency_sum == std::numeric_limits<std::uint64_t>::max());
  CHECK(stats.latency_sum_saturated);
  CHECK(stats.latency_max == 10);
  CHECK(stats.latency.count() == 2);
}

auto test_aggregation_and_deterministic_json() -> void {
  loglens::Aggregator aggregator;
  const auto worker = loglens::parse_line(
      "2026-07-12T01:00:00Z INFO worker 10 200");
  const auto api = loglens::parse_line(
      "2026-07-12T01:00:01Z ERROR api 20 500");
  CHECK(worker && api);
  CHECK(aggregator.add(*worker) == loglens::Aggregator::AddResult::added);
  CHECK(aggregator.add(*api) == loglens::Aggregator::AddResult::added);
  aggregator.add_malformed();

  CHECK(aggregator.accepted() == 2);
  CHECK(aggregator.malformed() == 1);
  const std::string first = loglens::render_json(aggregator);
  const std::string second = loglens::render_json(aggregator);
  CHECK(first == second);
  CHECK(first.find("\"schema_version\": 1") != std::string::npos);
  CHECK(first.find("\"accepted\": 2") != std::string::npos);
  CHECK(first.find("\"service\": \"api\"") <
        first.find("\"service\": \"worker\""));
}

auto test_service_limit() -> void {
  loglens::Aggregator aggregator(1);
  const auto first = loglens::parse_line(
      "2026-07-12T01:00:00Z INFO api 10 200");
  const auto second = loglens::parse_line(
      "2026-07-12T01:00:01Z INFO worker 20 200");
  CHECK(first && second);
  CHECK(aggregator.add(*first) == loglens::Aggregator::AddResult::added);
  CHECK(aggregator.add(*first) == loglens::Aggregator::AddResult::added);
  CHECK(aggregator.add(*second) ==
        loglens::Aggregator::AddResult::service_limit_exceeded);
  CHECK(aggregator.accepted() == 2);
  CHECK(aggregator.services().size() == 1);
}

auto test_bounded_reader() -> void {
  std::istringstream input("abc\r\n12345\nlast");
  std::string line;
  CHECK(loglens::read_bounded_line(input, line, 4) ==
        loglens::ReadLineResult::line);
  CHECK(line == "abc");
  CHECK(loglens::read_bounded_line(input, line, 4) ==
        loglens::ReadLineResult::too_long);
  CHECK(line.empty());
  CHECK(loglens::read_bounded_line(input, line, 4) ==
        loglens::ReadLineResult::line);
  CHECK(line == "last");
  CHECK(loglens::read_bounded_line(input, line, 4) ==
        loglens::ReadLineResult::end);
}

}  // namespace

auto main() -> int {
  test_parser_accepts_valid_lines();
  test_parser_error_table();
  test_all_histogram_boundaries();
  test_percentile_error_bound();
  test_latency_sum_saturation();
  test_aggregation_and_deterministic_json();
  test_service_limit();
  test_bounded_reader();
  std::cout << "All tests passed\n";
  return 0;
}
