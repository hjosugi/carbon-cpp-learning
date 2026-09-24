// Issue #6: compare::min_of and friends, in the same order as
// hands-on/carbon/comparisons/min_generic.carbon.

#include "generics/min.hpp"

#include <cstdint>
#include <iostream>

#include "check.hpp"

namespace {

using compare::Ordered;
using compare::Unordered;
using compare::Version;

// Opt-in, like Carbon impls: only types with an OrderedImpl satisfy Ordered.
static_assert(Ordered<std::int32_t>);
static_assert(Ordered<Version>);
static_assert(!Ordered<Unordered>);
static_assert(!Ordered<std::int64_t>);

// Everything below also runs at compile time.
static_assert(compare::min_of(3, 2) == 2);
static_assert(compare::min_of(Version{1, 5}, Version{1, 2}).minor == 2);

void test_min_of_integers() {
  // C++ integer literals are already `int` (std::int32_t here); Carbon needs
  // `3 as i32` because literals have type Core.IntLiteral.
  CHECK(compare::min_of(3, 2) == 2);
  CHECK(compare::min_of(-1, -1) == -1);
}

void test_min_of_versions() {
  const auto older = compare::min_of(Version{1, 5}, Version{1, 2});
  CHECK(older.major == 1);
  CHECK(older.minor == 2);
  CHECK(compare::min_of(Version{2, 0}, Version{1, 9}).major == 1);
}

void test_min3_calls_min() { CHECK(compare::min3_of(7, 9, 8) == 7); }

void test_body_outside_contract_compiles_for_int() {
  // The body uses operator<, which Ordered does not list. std::int32_t has
  // it, so this instantiation compiles and runs; Version would not
  // (expect-error/min_body_outside_contract.cpp).
  CHECK(compare::min_body_outside_contract(4, 3) == 3);
}

void test_explicit_specialization() {
  CHECK(compare::Describe<bool>::code == 1);
  CHECK(compare::Describe<std::int32_t>::code == 2);
}

}  // namespace

auto main() -> int {
  test_min_of_integers();
  test_min_of_versions();
  test_min3_calls_min();
  test_body_outside_contract_compiles_for_int();
  test_explicit_specialization();
  std::cout << "min_test: 5 tests passed\n";
  return 0;
}
