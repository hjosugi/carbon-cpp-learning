// Expected to fail in the check phase: initialization must name every field.
// C++ aggregate initialization value-initializes a missing designated field
// to 0 instead.
class Counter {
  var value: i32;
  var step: i32;
}

fn Make() -> Counter {
  return {.value = 1};
}
