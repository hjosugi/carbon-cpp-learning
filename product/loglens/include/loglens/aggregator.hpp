#pragma once

#include <array>
#include <bit>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>
#include <unordered_map>

#include "loglens/model.hpp"

namespace loglens {

class LatencyHistogram {
 public:
  static constexpr std::size_t kBucketCount = 33;

  void add(std::uint32_t latency_ms) noexcept;
  [[nodiscard]] auto count() const noexcept -> std::uint64_t;
  // Bucket index for a latency: the number of significant bits, so 0 maps to
  // bucket 0 and 2^(n-1)..2^n-1 map to bucket n (1..32).
  [[nodiscard]] static constexpr auto bucket_for(
      std::uint32_t latency_ms) noexcept -> std::size_t {
    return static_cast<std::size_t>(std::bit_width(latency_ms));
  }
  // Inclusive upper edge of a bucket. Buckets >= 32 saturate at UINT32_MAX,
  // so the shift below is always by 1..31 bits.
  [[nodiscard]] static constexpr auto bucket_upper(
      std::size_t bucket) noexcept -> std::uint64_t {
    if (bucket == 0) return 0;
    if (bucket >= 32) return std::numeric_limits<std::uint32_t>::max();
    return (std::uint64_t{1} << bucket) - 1;
  }
  [[nodiscard]] auto percentile_upper(double quantile) const noexcept
      -> std::uint64_t;

 private:
  std::array<std::uint64_t, kBucketCount> buckets_{};
  std::uint64_t count_{};
};

struct ServiceStats {
  std::uint64_t count{};
  std::uint64_t latency_sum{};
  std::uint32_t latency_max{};
  bool latency_sum_saturated{};
  std::array<std::uint64_t, 6> status_classes{};
  LatencyHistogram latency;

  void add_latency(std::uint32_t value) noexcept;
};

class Aggregator {
 public:
  enum class AddResult : std::uint8_t { added, service_limit_exceeded };

  explicit Aggregator(std::size_t max_services = 10'000) noexcept;

  [[nodiscard]] auto add(const Record& record) -> AddResult;
  void add_malformed() noexcept;

  [[nodiscard]] auto services() const noexcept
      -> const std::unordered_map<std::string, ServiceStats>&;
  [[nodiscard]] auto accepted() const noexcept -> std::uint64_t;
  [[nodiscard]] auto malformed() const noexcept -> std::uint64_t;

 private:
  std::size_t max_services_;
  std::unordered_map<std::string, ServiceStats> services_;
  std::uint64_t accepted_{};
  std::uint64_t malformed_{};
};

[[nodiscard]] auto render_json(const Aggregator& aggregator) -> std::string;

}  // namespace loglens
