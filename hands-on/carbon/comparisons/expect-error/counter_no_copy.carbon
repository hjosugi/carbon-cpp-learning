// Expected to fail in the check phase: a class is not copyable unless it
// implements `Core.Copy` (counter_value.carbon adds that impl). C++ classes
// are copyable by default and opt out with `= delete`.
class Counter {
  var value: i32;
}

fn Copy() -> i32 {
  var counter: Counter = {.value = 1};
  var copy: Counter = counter;
  return copy.value;
}
