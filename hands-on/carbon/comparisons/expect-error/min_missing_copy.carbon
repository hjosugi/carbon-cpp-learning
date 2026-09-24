// Expected to fail in the check phase: returning a `T` parameter copies it,
// and copying is not in the contract until `Core.Copy` is required.
interface Ordered {
  fn Less(self, other: Self) -> bool;
}

fn Min[T: Ordered](left: T, right: T) -> T {
  if (right.Less(left)) {
    return right;
  }
  return left;
}
