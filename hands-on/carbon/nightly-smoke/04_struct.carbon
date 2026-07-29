import Core library "io";

fn SmallestFactor(value: i32) -> {.factor: i32, .is_prime: bool, .iterations: i32} {
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

fn Run() {
  let result: {.factor: i32, .is_prime: bool, .iterations: i32} = SmallestFactor(21);
  Core.Print(result.factor);
  // The current Core.Print overload accepts i32, not bool.
  if (result.is_prime) {
    Core.Print(1);
  } else {
    Core.Print(0);
  }
  Core.Print(result.iterations);
}
