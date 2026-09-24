import Core library "io";

fn SmallestFactor(value: i32) -> (i32, bool) {
  var candidate: i32 = 2;
  while (candidate < value) {
    if (value % candidate == 0) {
      return (candidate, false);
    }
    ++candidate;
  }
  return (value, true);
}

fn Run() {
  let result: (i32, bool) = SmallestFactor(21);
  Core.Print(result.0);
  // The current Core.Print overload accepts i32, not bool.
  if (result.1) {
    Core.Print(1);
  } else {
    Core.Print(0);
  }
}
