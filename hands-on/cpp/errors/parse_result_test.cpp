// Issue #7: the three C++ error styles against the input and output of
// hands-on/carbon/comparisons/parse_result.input / parse_result.expected.

#include "errors/parse_result.hpp"

#include <array>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string_view>
#include <variant>

#include "check.hpp"

namespace {

struct Case {
  std::string_view line;
  std::int32_t reported;  // value for Ok, negated code for an error
};

// Same lines and expected output as the Carbon lab.
constexpr std::array kCases{
    Case{"17", 17},
    Case{"", -1},
    Case{"1x", -2},
    Case{"2147483647", 2147483647},
    Case{"2147483648", -3},
    Case{"0", 0},
    Case{"-5", -2},
    Case{" 7", -2},
    Case{"99999999999999999999", -3},
};

void test_expected_and_variant_agree_with_carbon() {
  for (const auto& test_case : kCases) {
    CHECK(compare::report(compare::parse_latency(test_case.line)) ==
          test_case.reported);
    CHECK(compare::report(compare::parse_latency_event(test_case.line)) ==
          test_case.reported);
  }
}

void test_expected_carries_one_error_type() {
  const auto result = compare::parse_latency("1x");
  CHECK(!result.has_value());
  CHECK(result.error() == compare::ParseErrorCode::not_digit);
}

void test_variant_alternatives_carry_their_own_payload() {
  // Only NotDigit has a position; Empty and Overflow carry nothing.
  const auto event = compare::parse_latency_event("12x4");
  const auto* not_digit = std::get_if<compare::NotDigit>(&event);
  CHECK(not_digit != nullptr);
  CHECK(not_digit->position == 2);
  CHECK(std::holds_alternative<compare::Overflow>(
      compare::parse_latency_event("2147483648")));
}

void test_invalid_input_is_a_normal_event() {
  // A stream with mostly bad lines is processed to the end without any
  // exceptional control flow: every line yields a value.
  int errors = 0;
  for (const auto& test_case : kCases) {
    if (!compare::parse_latency(test_case.line)) ++errors;
  }
  CHECK(errors == 6);
}

void test_exception_version_hides_the_error_path() {
  CHECK(compare::parse_latency_or_throw("17") == 17);
  bool thrown = false;
  try {
    static_cast<void>(compare::parse_latency_or_throw("1x"));
  } catch (const std::invalid_argument&) {
    thrown = true;
  }
  CHECK(thrown);
}

}  // namespace

auto main() -> int {
  test_expected_and_variant_agree_with_carbon();
  test_expected_carries_one_error_type();
  test_variant_alternatives_carry_their_own_payload();
  test_invalid_input_is_a_normal_event();
  test_exception_version_hides_the_error_path();
  std::cout << "parse_result_test: 5 tests passed\n";
  return 0;
}
