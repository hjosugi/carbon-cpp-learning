// Issue #6: impl specialization on the pinned nightly.
// A blanket impl covers every copyable type, and a more specific impl for
// `i32` overlaps it. The overlap rule (docs/design/generics/details.md,
// "Overlap rule") picks the impl whose type structure matches best, also
// inside generic code. C++ gets the same effect with an explicit class
// template specialization (hands-on/cpp/generics/min.hpp, `Describe`).
import Core library "io";

interface Describe {
  fn Code(self) -> i32;
}

impl forall [T: Core.Copy] T as Describe {
  fn Code(unused self) -> i32 {
    return 1;
  }
}

impl i32 as Describe {
  fn Code(unused self) -> i32 {
    return 2;
  }
}

fn CodeOf[T: Describe](value: T) -> i32 {
  return value.Code();
}

fn Run() {
  Core.Print(CodeOf(true));      // 1: blanket impl
  Core.Print(CodeOf(5 as i32));  // 2: the i32 impl wins
  // An impl declared outside the class does not add names to the type, so
  // outside generic code the member is named through the interface.
  Core.Print((5 as i32).(Describe.Code)());  // 2
}
