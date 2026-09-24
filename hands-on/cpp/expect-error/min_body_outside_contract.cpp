// Expected to fail: Version satisfies Ordered, so the call is accepted, but
// the body uses operator<, which Ordered does not require. C++ reports it at
// instantiation; Carbon rejects the same body at its definition
// (hands-on/carbon/comparisons/expect-error/min_body_uses_less_than.carbon).
#include "generics/min.hpp"

auto older() -> compare::Version {
  return compare::min_body_outside_contract(compare::Version{1, 5},
                                            compare::Version{1, 2});
}
