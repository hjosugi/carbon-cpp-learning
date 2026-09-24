// Expected to fail: min_unconstrained has no contract, so the missing
// operator< for Version is found only at instantiation, inside the template
// body in min.hpp.
#include "generics/min.hpp"

auto older() -> compare::Version {
  return compare::min_unconstrained(compare::Version{1, 5},
                                    compare::Version{1, 2});
}
