// Expected to fail in the check phase: `Min(a, b)` creates a temporary `T`
// that must be destroyed, and destruction is not in the contract until
// `Core.Destroy` is required.
interface Ordered {
  fn Less(self, other: Self) -> bool;
}

fn Min[T: Ordered & Core.Copy](left: T, right: T) -> T {
  if (right.Less(left)) {
    return right;
  }
  return left;
}

fn Min3[T: Ordered & Core.Copy](a: T, b: T, c: T) -> T {
  return Min(Min(a, b), c);
}
