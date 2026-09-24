// Kata 1 (issue #4): Clamp with boundary inputs.
// Starting point: nightly-smoke/01_functions.carbon.
import Core library "io";

// Contract: requires low <= high.
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
  // Below low, at low, inside, at high, above high.
  Core.Print(Clamp(-5, 0, 10));
  Core.Print(Clamp(0, 0, 10));
  Core.Print(Clamp(5, 0, 10));
  Core.Print(Clamp(10, 0, 10));
  Core.Print(Clamp(15, 0, 10));
}
