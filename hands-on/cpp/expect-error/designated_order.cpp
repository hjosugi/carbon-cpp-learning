// Expected to fail: C++20 designated initializers must follow declaration
// order. Carbon matches fields by name, so {.step = 10, .value = 1} compiles
// there. GCC makes this an error; Clang warns (-Wreorder-init-list), which
// the lab's -Werror turns into an error.
#include "counter/counter.hpp"

auto make_state() -> compare::CounterState {
  return compare::CounterState{.step = 10, .value = 1};
}
