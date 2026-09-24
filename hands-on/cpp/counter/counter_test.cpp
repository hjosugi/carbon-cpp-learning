// Issue #5: value semantics of compare::Counter, step by step in the same
// order as hands-on/carbon/comparisons/counter_value.carbon.

#include "counter/counter.hpp"

#include <cstddef>
#include <cstdint>
#include <iostream>
#include <memory>
#include <type_traits>
#include <utility>

#include "check.hpp"

namespace {

using compare::Counter;
using compare::CounterLog;
using compare::CounterState;

// Layout and special members are compile-time facts.
static_assert(sizeof(Counter) == 2 * sizeof(std::int32_t));
static_assert(offsetof(CounterState, value) == 0);
static_assert(offsetof(CounterState, step) == sizeof(std::int32_t));
static_assert(std::is_trivially_copyable_v<Counter>);
static_assert(std::is_nothrow_move_constructible_v<Counter>);
static_assert(!std::is_copy_constructible_v<CounterLog>);
static_assert(std::is_nothrow_move_constructible_v<CounterLog>);
// Counter::create is constexpr, so the whole value type works at compile time.
static_assert([] {
  auto counter = Counter::create(0, 2);
  counter.increment();
  return counter.get();
}() == 2);

void test_designated_initializers() {
  // Designators must follow declaration order (expect-error/designated_order.cpp).
  constexpr CounterState state{.value = 1, .step = 10};
  CHECK(state.value == 1);
  CHECK(state.step == 10);
  // The language value-initializes a missing designated field to 0; only the
  // -Wextra warning (-Wmissing-field-initializers) flags it, so it is silenced
  // here to show the rule. Carbon rejects the same literal with "missing value
  // for field `step`" (expect-error/counter_missing_field.carbon).
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
  constexpr CounterState partial{.value = 1};
#pragma GCC diagnostic pop
  CHECK(partial.step == 0);
}

void test_copy_is_independent() {
  auto counter = Counter::create(0, 1);
  counter.increment();
  auto copy = counter;  // copy constructor, implicitly defined
  counter.increment();
  CHECK(counter.get() == 2);
  CHECK(copy.get() == 1);
}

void test_reference_borrow() {
  auto counter = Counter::create(2, 1);
  compare::bump(counter);
  CHECK(counter.get() == 3);
}

void test_by_value_parameter() {
  // A prvalue initializes the parameter directly (guaranteed copy elision).
  CHECK(compare::finish(Counter::create(41, 1)) == 42);
  // An lvalue is copied, so the caller's object is unchanged.
  const auto counter = Counter::create(3, 1);
  CHECK(compare::finish(counter) == 4);
  CHECK(counter.get() == 3);
}

void test_const_reference_observes_mutation() {
  // A const reference is a read-only view, not a snapshot: it sees later
  // mutation, and that is well-defined in C++. The Carbon `let` version is
  // erroneous by design (counter_let_alias.carbon).
  auto counter = Counter::create(1, 1);
  const Counter& view = counter;
  counter.increment();
  CHECK(view.get() == 2);
}

void test_move_of_trivial_type_is_a_copy() {
  // C++ move is non-destructive. For a trivially copyable type it copies, and
  // the moved-from object stays usable with its old value.
  auto counter = Counter::create(5, 1);
  auto moved = std::move(counter);
  CHECK(moved.get() == 5);
  CHECK(counter.get() == 5);  // NOLINT(bugprone-use-after-move): the point
}

void test_move_only_owner() {
  CounterLog log;
  log.record(Counter::create(1, 1));
  log.record(Counter::create(2, 1));
  CounterLog owner = std::move(log);
  CHECK(owner.size() == 2);
}

void test_unique_ptr_ownership() {
  // Heap ownership without an owning raw pointer.
  auto owned = std::make_unique<Counter>(Counter::create(7, 1));
  owned->increment();
  std::unique_ptr<Counter> next = std::move(owned);
  CHECK(owned == nullptr);  // guaranteed for std::unique_ptr
  CHECK(next->get() == 8);
}

void test_destructor_runs_at_scope_exit() {
  // The Carbon `destroy` method is not run by the pinned nightly
  // (counter_destroy.carbon); the C++ destructor always runs here.
  int destroyed = 0;
  {
    const compare::ScopeProbe probe{destroyed};
    CHECK(destroyed == 0);
  }
  CHECK(destroyed == 1);
}

}  // namespace

auto main() -> int {
  test_designated_initializers();
  test_copy_is_independent();
  test_reference_borrow();
  test_by_value_parameter();
  test_const_reference_observes_mutation();
  test_move_of_trivial_type_is_a_copy();
  test_move_only_owner();
  test_unique_ptr_ownership();
  test_destructor_runs_at_scope_exit();
  std::cout << "counter_test: 9 tests passed\n";
  return 0;
}
