import Core library "io";

fn SmallestFactor(value: i32) -> (i32, bool, i32) {
  var candidate: i32 = 2;
  var iterations: i32 = 0;
  while (candidate < value) {
    ++iterations;
    if (value % candidate == 0) {
      return (candidate, false, iterations);
    }
    ++candidate;
  }
  return (value, true, iterations);
}

fn Run() {
  let result: (i32, bool, i32) = SmallestFactor(21);
  Core.Print(result.0);
  // The current Core.Print overload accepts i32, not bool.
  if (result.1) {
    Core.Print(1);
  } else {
    Core.Print(0);
  }
  Core.Print(result.2);
}
