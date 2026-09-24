#pragma once

// Issue #6: C++23 counterpart of hands-on/carbon/comparisons/min_generic.carbon.

#include <concepts>
#include <cstdint>

namespace compare {

// Mirrors the Carbon `Ordered` interface. A type opts in by specializing
// OrderedImpl, much like `impl i32 as Ordered`, including for types we do not
// own. The primary template is left undefined: no impl by default.
template <typename T>
struct OrderedImpl;

// std::copyable plays the role of `Core.Copy`. It also implies
// std::destructible, which Carbon has to spell out as `Core.Destroy`.
template <typename T>
concept Ordered =
    std::copyable<T> && requires(const T& left, const T& right) {
      { OrderedImpl<T>::less(left, right) } -> std::same_as<bool>;
    };

template <>
struct OrderedImpl<std::int32_t> {
  [[nodiscard]] static constexpr auto less(std::int32_t left,
                                           std::int32_t right) noexcept
      -> bool {
    return left < right;
  }
};

struct Version {
  std::int32_t major;
  std::int32_t minor;
};

template <>
struct OrderedImpl<Version> {
  [[nodiscard]] static constexpr auto less(const Version& left,
                                           const Version& right) noexcept
      -> bool {
    if (left.major != right.major) return left.major < right.major;
    return left.minor < right.minor;
  }
};

// Copyable, but with no OrderedImpl specialization.
struct Unordered {
  std::int32_t id;
};

// Constrained template. Callers are checked against the concept, and ties
// return `left`, like std::min.
template <Ordered T>
[[nodiscard]] constexpr auto min_of(const T& left, const T& right) -> T {
  return OrderedImpl<T>::less(right, left) ? right : left;
}

template <Ordered T>
[[nodiscard]] constexpr auto min3_of(const T& first, const T& second,
                                     const T& third) -> T {
  return min_of(min_of(first, second), third);
}

// Constrained, but the body uses operator<, which Ordered does not require.
// C++ does not check a template body against its constraints, so this
// definition compiles and even works for std::int32_t. Carbon rejects the
// same body at its definition (expect-error/min_body_uses_less_than.carbon).
template <Ordered T>
[[nodiscard]] constexpr auto min_body_outside_contract(const T& left,
                                                       const T& right) -> T {
  return right < left ? right : left;
}

// Unconstrained template: no contract at all, so every error is found at
// instantiation, inside the body.
template <typename T>
[[nodiscard]] constexpr auto min_unconstrained(const T& left, const T& right)
    -> T {
  return right < left ? right : left;
}

// Explicit specialization, the C++ analog of the overlapping `impl i32 as
// Describe` in generic_specialization.carbon.
template <typename T>
struct Describe {
  static constexpr std::int32_t code = 1;
};

template <>
struct Describe<std::int32_t> {
  static constexpr std::int32_t code = 2;
};

}  // namespace compare
