#pragma once

// Issue #5: C++23 counterpart of hands-on/carbon/comparisons/counter_value.carbon.

#include <cstddef>
#include <cstdint>
#include <vector>

namespace compare {

// Value type. The rule of zero gives it copy and move operations for free;
// C++ types are copyable unless they opt out.
class Counter {
 public:
  [[nodiscard]] static constexpr auto create(std::int32_t value,
                                             std::int32_t step) noexcept
      -> Counter {
    return Counter{value, step};
  }

  constexpr void increment() noexcept { value_ += step_; }

  [[nodiscard]] constexpr auto get() const noexcept -> std::int32_t {
    return value_;
  }

 private:
  constexpr Counter(std::int32_t value, std::int32_t step) noexcept
      : value_{value}, step_{step} {}

  // Members are initialized in declaration order, whatever order the
  // mem-initializer list uses (-Wreorder warns when they disagree).
  std::int32_t value_;
  std::int32_t step_;
};

// Aggregate with public fields, used for designated initializers.
struct CounterState {
  std::int32_t value;
  std::int32_t step;
};

// Non-owning mutable access, like `Bump(counter: Counter*)` in Carbon.
constexpr void bump(Counter& counter) noexcept { counter.increment(); }

// By-value parameter: the function owns its own `Counter`, like
// `Finish(var counter: Counter)` in Carbon.
[[nodiscard]] constexpr auto finish(Counter counter) noexcept -> std::int32_t {
  counter.increment();
  return counter.get();
}

// Move-only owner of heap memory. The copy operations are deleted, which is
// the C++ equivalent of a Carbon class without a `Core.Copy` impl.
class CounterLog {
 public:
  CounterLog() = default;
  CounterLog(const CounterLog&) = delete;
  auto operator=(const CounterLog&) -> CounterLog& = delete;
  CounterLog(CounterLog&&) noexcept = default;
  auto operator=(CounterLog&&) noexcept -> CounterLog& = default;
  ~CounterLog() = default;

  void record(const Counter& counter) { entries_.push_back(counter.get()); }

  [[nodiscard]] auto size() const noexcept -> std::size_t {
    return entries_.size();
  }

 private:
  // std::vector owns the allocation; no owning raw pointer is needed.
  std::vector<std::int32_t> entries_;
};

// Counts destructor calls through a reference, without owning anything.
class ScopeProbe {
 public:
  explicit ScopeProbe(int& destroyed) noexcept : destroyed_{destroyed} {}
  ScopeProbe(const ScopeProbe&) = delete;
  auto operator=(const ScopeProbe&) -> ScopeProbe& = delete;
  ScopeProbe(ScopeProbe&&) = delete;
  auto operator=(ScopeProbe&&) -> ScopeProbe& = delete;
  ~ScopeProbe() { ++destroyed_; }

 private:
  int& destroyed_;
};

}  // namespace compare
