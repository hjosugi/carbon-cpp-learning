// Issue #5: records what the pinned nightly does with an ERRONEOUS program.
//
// `let view: Counter = counter;` binds a value to the object without copying
// it. The design (docs/design/values.md, "Value expressions") says that any
// later mutation of the object ends the value binding's lifetime and makes
// using `view` an error ("erroneous", not undefined behavior). The pinned
// nightly does not diagnose this yet: `view` reads the mutated object.
// If a newer nightly starts rejecting this file, update the evidence doc.
import Core library "io";

class Counter {
  var value: i32;

  fn Increment(ref self) {
    ++self.value;
  }

  fn Get(self) -> i32 {
    return self.value;
  }
}

// `Core.Copy` exists, yet `let` still does not copy.
impl Counter as Core.Copy {
  fn Op(self) -> Self {
    return {.value = self.value};
  }
}

fn Run() {
  var counter: Counter = {.value = 1};
  let view: Counter = counter;
  counter.Increment();
  // Erroneous by design: `view` is used after `counter` was mutated.
  Core.Print(view.Get());  // prints 2 on the pinned nightly, not 1
}
