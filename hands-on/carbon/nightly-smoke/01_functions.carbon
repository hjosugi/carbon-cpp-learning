import Core library "io";

fn Double(value: i32) -> i32 {
  return value * 2;
}

fn Clamp(value: i32, low: i32, high: i32) -> i32 {
  if (value < low) {
    return low;
  }
  if (value > high) {
    return high;
  }
  return value;
}

fn Run() {
  let answer: i32 = Double(21);
  Core.Print(answer);
  // Clamp boundary tests: below low, at low, middle, at high, above high.
  Core.Print(Clamp(-5, 0, 10));
  Core.Print(Clamp(0, 0, 10));
  Core.Print(Clamp(5, 0, 10));
  Core.Print(Clamp(10, 0, 10));
  Core.Print(Clamp(15, 0, 10));
}
