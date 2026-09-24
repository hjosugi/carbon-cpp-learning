// Issue #5: records that a user `destroy` method is accepted but not run.
//
// docs/design/classes.md ("Destructors") says `fn destroy(ref self)` runs when
// a variable goes out of scope, like a C++ destructor. The pinned nightly
// compiles this class, but the call to `destroy` is not emitted, so the
// program prints 7 and 1 and never -7. If a newer nightly starts running the
// destructor, the expected output changes and the evidence doc needs updating.
import Core library "io";

class Counter {
  var value: i32;

  fn Get(self) -> i32 {
    return self.value;
  }

  // Design-only: should print the negated value at scope exit.
  fn destroy(ref self) {
    Core.Print(-self.value);
  }
}

fn Scope() {
  var counter: Counter = {.value = 7};
  Core.Print(counter.Get());  // 7
}  // By design, `destroy` would print -7 here.

fn Run() {
  Scope();
  Core.Print(1);  // 1
}
