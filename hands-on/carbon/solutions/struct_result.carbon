// Kata 3 (issue #4): the same API with a named struct result.
// Compare with tuple_loop_count.carbon: fields are read by name instead of
// position, so the call site documents itself and fields cannot be swapped.
import Core library "io";

fn SmallestFactor(value: i32) -> {.factor: i32, .is_prime: bool, .iterations: i32} {
  if (value <= 1) {
    return {.factor = value, .is_prime = false, .iterations = 0};
  }
  var candidate: i32 = 2;
  var iterations: i32 = 0;
  while (candidate < value) {
    ++iterations;
    if (value % candidate == 0) {
      return {.factor = candidate, .is_prime = false, .iterations = iterations};
    }
    ++candidate;
  }
  return {.factor = value, .is_prime = true, .iterations = iterations};
}

fn Show(value: i32) {
  let result: {.factor: i32, .is_prime: bool, .iterations: i32} =
      SmallestFactor(value);
  Core.Print(result.factor);
  // The current Core.Print overload accepts i32, not bool.
  if (result.is_prime) {
    Core.Print(1);
  } else {
    Core.Print(0);
  }
  Core.Print(result.iterations);
}

fn Run() {
  Show(1);
  Show(2);
  Show(13);
  Show(21);
}
