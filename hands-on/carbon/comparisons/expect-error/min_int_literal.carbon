// Expected to fail in the check phase: `3` and `2` have type
// `Core.IntLiteral`, which does not implement `Ordered`. min_generic.carbon
// converts the arguments with `as i32`.
interface Ordered {
  fn Less(self, other: Self) -> bool;
}

impl i32 as Ordered {
  fn Less(self, other: Self) -> bool {
    return self < other;
  }
}

fn Min[T: Ordered & Core.Copy](left: T, right: T) -> T {
  if (right.Less(left)) {
    return right;
  }
  return left;
}

fn Two() -> i32 {
  return Min(3, 2);
}
