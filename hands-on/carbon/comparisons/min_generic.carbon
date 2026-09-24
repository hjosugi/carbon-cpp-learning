// Issue #6: a definition-checked `Min` on the pinned nightly.
// C++ counterpart: hands-on/cpp/generics/min.hpp and min_test.cpp.
// Check: ./scripts/run-carbon-comparisons.sh
import Core library "io";

// The contract: everything `Min` may do with a `T` is listed here or in the
// other interfaces named in its signature.
interface Ordered {
  fn Less(self, other: Self) -> bool;
}

// An impl can be written for a type that is not ours, such as `i32`.
impl i32 as Ordered {
  fn Less(self, other: Self) -> bool {
    return self < other;
  }
}

class Version {
  var major: i32;
  var minor: i32;
}

impl Version as Core.Copy {
  fn Op(self) -> Self {
    return {.major = self.major, .minor = self.minor};
  }
}

impl Version as Ordered {
  fn Less(self, other: Self) -> bool {
    if (self.major != other.major) {
      return self.major < other.major;
    }
    return self.minor < other.minor;
  }
}

// `Core.Copy` is required because `left` / `right` are returned by copy.
// Without it the body is rejected (expect-error/min_missing_copy.carbon).
// Ties return `left`, like std::min.
fn Min[T: Ordered & Core.Copy](left: T, right: T) -> T {
  if (right.Less(left)) {
    return right;
  }
  return left;
}

// A generic calling a generic is checked against `Min`'s signature only. The
// temporary returned by the inner `Min` must be destroyed, so `Core.Destroy`
// is part of the contract (expect-error/min3_missing_destroy.carbon).
fn Min3[T: Ordered & Core.Copy & Core.Destroy](a: T, b: T, c: T) -> T {
  return Min(Min(a, b), c);
}

fn Run() {
  // Integer literals have type `Core.IntLiteral`, which does not implement
  // `Ordered`, so the arguments are converted to `i32` first.
  Core.Print(Min(3 as i32, 2 as i32));             // 2
  Core.Print(Min(-1 as i32, -1 as i32));           // -1
  let older: Version = Min({.major = 1, .minor = 5} as Version,
                           {.major = 1, .minor = 2} as Version);
  Core.Print(older.major);                          // 1
  Core.Print(older.minor);                          // 2
  Core.Print(Min3(7 as i32, 9 as i32, 8 as i32));  // 7
}
