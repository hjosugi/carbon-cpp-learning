#include "loglens/aggregator.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <limits>
#include <sstream>
#include <string>
#include <vector>

namespace loglens {

Aggregator::Aggregator(std::size_t max_services) noexcept
    : max_services_(max_services) {}

void LatencyHistogram::add(std::uint32_t latency_ms) noexcept {
  ++buckets_[bucket_for(latency_ms)];
  ++count_;
}

auto LatencyHistogram::count() const noexcept -> std::uint64_t { return count_; }

auto LatencyHistogram::percentile_upper(double quantile) const noexcept
    -> std::uint64_t {
  if (count_ == 0) return 0;
  const auto target = static_cast<std::uint64_t>(
      std::ceil(std::clamp(quantile, 0.0, 1.0) * static_cast<double>(count_)));
  std::uint64_t seen = 0;
  for (std::size_t bucket = 0; bucket < buckets_.size(); ++bucket) {
    seen += buckets_[bucket];
    if (seen >= std::max<std::uint64_t>(target, 1)) {
      return bucket_upper(bucket);
    }
  }
  return std::numeric_limits<std::uint32_t>::max();
}

void ServiceStats::add_latency(std::uint32_t value) noexcept {
  if (latency_sum > std::numeric_limits<std::uint64_t>::max() - value) {
    latency_sum = std::numeric_limits<std::uint64_t>::max();
    latency_sum_saturated = true;
  } else {
    latency_sum += value;
  }
  latency_max = std::max(latency_max, value);
  latency.add(value);
}

auto Aggregator::add(const Record& record) -> AddResult {
  auto existing = services_.find(std::string(record.service));
  if (existing == services_.end()) {
    if (services_.size() >= max_services_) {
      return AddResult::service_limit_exceeded;
    }
    existing = services_.try_emplace(std::string(record.service)).first;
  }
  auto& stats = existing->second;
  ++stats.count;
  ++accepted_;

  stats.add_latency(record.latency_ms);

  const auto status_class = static_cast<std::size_t>(record.status / 100);
  ++stats.status_classes[status_class];
  return AddResult::added;
}

void Aggregator::add_malformed() noexcept { ++malformed_; }

auto Aggregator::services() const noexcept
    -> const std::unordered_map<std::string, ServiceStats>& {
  return services_;
}

auto Aggregator::accepted() const noexcept -> std::uint64_t { return accepted_; }

auto Aggregator::malformed() const noexcept -> std::uint64_t { return malformed_; }

auto render_json(const Aggregator& aggregator) -> std::string {
  std::vector<std::string> names;
  names.reserve(aggregator.services().size());
  for (const auto& [name, stats] : aggregator.services()) {
    static_cast<void>(stats);
    names.push_back(name);
  }
  std::ranges::sort(names);

  std::ostringstream output;
  output << std::setprecision(std::numeric_limits<double>::max_digits10);
  output << "{\n  \"schema_version\": 1,\n  \"accepted\": " << aggregator.accepted()
         << ",\n  \"malformed\": " << aggregator.malformed()
         << ",\n  \"services\": [";

  for (std::size_t index = 0; index < names.size(); ++index) {
    const auto& name = names[index];
    const auto& stats = aggregator.services().at(name);
    const auto errors = stats.status_classes[4] + stats.status_classes[5];
    const double average = stats.count == 0
                               ? 0.0
                               : static_cast<double>(stats.latency_sum) /
                                     static_cast<double>(stats.count);
    const double error_rate = stats.count == 0
                                  ? 0.0
                                  : static_cast<double>(errors) /
                                        static_cast<double>(stats.count);

    output << "\n    {\"service\": \"" << name << "\", \"count\": "
           << stats.count << ", \"error_rate\": " << error_rate
           << ", \"latency_avg_ms\": " << average
           << ", \"latency_max_ms\": " << stats.latency_max
           << ", \"latency_p95_upper_ms\": "
           << stats.latency.percentile_upper(0.95)
           << ", \"latency_sum_saturated\": "
           << (stats.latency_sum_saturated ? "true" : "false") << '}';
    if (index + 1 != names.size()) output << ',';
  }

  output << "\n  ]\n}\n";
  return output.str();
}

}  // namespace loglens
