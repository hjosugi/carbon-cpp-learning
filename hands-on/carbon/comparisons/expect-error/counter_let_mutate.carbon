// Expected to fail in the check phase: a `let` binding is a value, so a
// `ref self` method cannot be called on it. C++ rejects the same call on a
// `const Counter` for a similar reason.
class Counter {
  var value: i32;

  fn Increment(ref self) {
    ++self.value;
  }
}

fn Mutate() {
  let counter: Counter = {.value = 1};
  counter.Increment();
}
