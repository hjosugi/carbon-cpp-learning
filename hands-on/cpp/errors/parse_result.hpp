#pragma once

// Issue #7: C++23 counterparts of hands-on/carbon/comparisons/parse_result.carbon.
// The same error contract is written three ways: std::expected, std::variant,
// and exceptions.

#include <cstddef>
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string_view>
#include <utility>
#include <variant>

// loglens::Result is std::expected when the standard library provides it, and
// a small std::variant adapter otherwise (Clang 18 with libstdc++ 13 in CI).
#include "loglens/result.hpp"

namespace compare {

// Error contract, one code per failure. The numbers match the Carbon lab.
enum class ParseErrorCode : std::uint8_t {
  empty = 1,      // the line has no characters
  not_digit = 2,  // a character is not 0-9
  overflow = 3,   // the value does not fit in std::int32_t
};

inline constexpr std::int64_t kMaxLatency =
    std::numeric_limits<std::int32_t>::max();

// 1. std::expected: one value type and one error type. The first error wins.
[[nodiscard]] inline auto parse_latency(std::string_view text) noexcept
    -> loglens::Result<std::int32_t, ParseErrorCode> {
  if (text.empty()) return loglens::unexpected(ParseErrorCode::empty);
  std::int64_t total = 0;
  for (const char character : text) {
    if (character < '0' || character > '9') {
      return loglens::unexpected(ParseErrorCode::not_digit);
    }
    total = total * 10 + (character - '0');
    if (total > kMaxLatency) {
      return loglens::unexpected(ParseErrorCode::overflow);
    }
  }
  return static_cast<std::int32_t>(total);
}

// 2. std::variant: one type per alternative, each with its own payload. This
// is the closest C++ shape to the design-only Carbon `choice ParseResult`.
struct Ok {
  std::int32_t value;
};
struct Empty {};
struct NotDigit {
  std::size_t position;
};
struct Overflow {};

using ParseEvent = std::variant<Ok, Empty, NotDigit, Overflow>;

[[nodiscard]] inline auto parse_latency_event(std::string_view text) noexcept
    -> ParseEvent {
  if (text.empty()) return Empty{};
  std::int64_t total = 0;
  for (std::size_t position = 0; position < text.size(); ++position) {
    const char character = text[position];
    if (character < '0' || character > '9') return NotDigit{position};
    total = total * 10 + (character - '0');
    if (total > kMaxLatency) return Overflow{};
  }
  return Ok{static_cast<std::int32_t>(total)};
}

// 3. Exceptions: the error leaves through a hidden path, and the caller must
// know to catch it.
[[nodiscard]] inline auto parse_latency_or_throw(std::string_view text)
    -> std::int32_t {
  const auto result = parse_latency(text);
  if (!result) throw std::invalid_argument("invalid latency");
  return *result;
}

template <typename... Handlers>
struct Overloaded : Handlers... {
  using Handlers::operator()...;
};

// Reports like the Carbon lab: the value for Ok, the negated code otherwise.
// std::visit rejects a visitor that misses an alternative at compile time
// (expect-error/variant_missing_alternative.cpp).
[[nodiscard]] inline auto report(const ParseEvent& event) -> std::int32_t {
  return std::visit(
      Overloaded{
          [](const Ok& ok) { return ok.value; },
          [](const Empty&) { return -1; },
          [](const NotDigit&) { return -2; },
          [](const Overflow&) { return -3; },
      },
      event);
}

// -Wswitch (in -Wall) flags a missing enumerator; with -Werror it is an error
// (expect-error/switch_missing_enumerator.cpp).
[[nodiscard]] inline auto report(
    const loglens::Result<std::int32_t, ParseErrorCode>& result)
    -> std::int32_t {
  if (result) return *result;
  switch (result.error()) {
    case ParseErrorCode::empty:
      return -1;
    case ParseErrorCode::not_digit:
      return -2;
    case ParseErrorCode::overflow:
      return -3;
  }
  std::unreachable();
}

}  // namespace compare
