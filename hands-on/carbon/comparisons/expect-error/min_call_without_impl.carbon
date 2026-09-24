// Expected to fail in the check phase: `Unordered` has no `Ordered` impl.
// The error points at the call and names the unmet contract; the body of
// `Min` is not looked at.
interface Ordered {
  fn Less(self, other: Self) -> bool;
}

class Unordered {
  var id: i32;
}

impl Unordered as Core.Copy {
  fn Op(self) -> Self {
    return {.id = self.id};
  }
}

fn Min[T: Ordered & Core.Copy](left: T, right: T) -> T {
  if (right.Less(left)) {
    return right;
  }
  return left;
}

fn Pick() -> Unordered {
  let first: Unordered = {.id = 1};
  let second: Unordered = {.id = 2};
  return Min(first, second);
}
