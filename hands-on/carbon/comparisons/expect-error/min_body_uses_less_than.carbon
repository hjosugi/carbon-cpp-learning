// Expected to fail in the check phase: the body uses `<`, which is not in the
// `Ordered` contract. Carbon checks the generic definition itself, so this is
// rejected although nothing calls `Min`. The C++ template with the same body
// compiles until it is instantiated with a type that has no `operator<`
// (hands-on/cpp/expect-error/min_unconstrained_body.cpp).
interface Ordered {
  fn Less(self, other: Self) -> bool;
}

fn Min[T: Ordered & Core.Copy](left: T, right: T) -> T {
  if (right < left) {
    return right;
  }
  return left;
}
