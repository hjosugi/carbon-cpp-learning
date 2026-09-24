// Issue #5: `Counter` as a value type on the pinned nightly.
// C++ counterpart: hands-on/cpp/counter/counter.hpp and counter_test.cpp.
// Check: ./scripts/run-carbon-comparisons.sh
import Core library "io";

class Counter {
  // Fields are laid out in declaration order.
  var value: i32;
  var step: i32;

  // No constructors: a factory function returns an initializing expression,
  // and the struct literal must name every field.
  fn Create(value: i32, step: i32) -> Self {
    return {.value = value, .step = step};
  }

  // `ref self`: mutates the object the method is called on.
  fn Increment(ref self) {
    self.value += self.step;
  }

  // `self`: a read-only value receiver.
  fn Get(self) -> i32 {
    return self.value;
  }
}

// Copy is opt-in. Without this impl, `var copy: Counter = counter;` is
// rejected (expect-error/counter_no_copy.carbon).
impl Counter as Core.Copy {
  fn Op(self) -> Self {
    return {.value = self.value, .step = self.step};
  }
}

// Non-owning mutable access: the caller keeps ownership of the object.
fn Bump(counter: Counter*) {
  counter->Increment();
}

// Consuming parameter: the function owns a `Counter` object of its own.
fn Finish(var counter: Counter) -> i32 {
  counter.Increment();
  return counter.Get();
}

fn Run() {
  // Initialization matches fields by name, so the literal order is free.
  let reordered: Counter = {.step = 10, .value = 1};
  Core.Print(reordered.Get());                // 1

  var counter: Counter = Counter.Create(0, 1);
  counter.Increment();
  // Copy through `Core.Copy`: the copy is an independent object.
  var copy: Counter = counter;
  counter.Increment();
  Core.Print(counter.Get());                  // 2
  Core.Print(copy.Get());                     // 1

  // Borrow through a pointer; nothing is allocated or freed.
  Bump(&counter);
  Core.Print(counter.Get());                  // 3

  // A temporary initializes the parameter directly, so no copy is needed.
  Core.Print(Finish(Counter.Create(41, 1)));  // 42
  // A named variable is copied into the parameter (needs `Core.Copy`),
  // so the caller's object is unchanged.
  Core.Print(Finish(counter));                // 4
  Core.Print(counter.Get());                  // 3
}
