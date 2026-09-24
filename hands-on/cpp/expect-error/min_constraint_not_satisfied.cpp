// Expected to fail: Unordered has no OrderedImpl, so it does not satisfy
// Ordered. The error points at the call and names the unmet constraint, like
// Carbon's expect-error/min_call_without_impl.carbon.
#include "generics/min.hpp"

auto pick() -> compare::Unordered {
  return compare::min_of(compare::Unordered{1}, compare::Unordered{2});
}
