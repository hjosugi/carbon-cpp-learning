// Kata 2 (issue #4): return the loop count as a third tuple element.
// Starting point: nightly-smoke/03_tuple.carbon.
import Core library "io";

// Returns (smallest factor, is prime, loop iterations).
// Contract: values <= 1 are not prime and run no iterations.
fn SmallestFactor(value: i32) -> (i32, bool, i32) {
  if (value <= 1) {
    return (value, false, 0);
  }
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

fn Show(value: i32) {
  let result: (i32, bool, i32) = SmallestFactor(value);
  Core.Print(result.0);
  // The current Core.Print overload accepts i32, not bool.
  if (result.1) {
    Core.Print(1);
  } else {
    Core.Print(0);
  }
  Core.Print(result.2);
}

fn Run() {
  Show(1);   // boundary: not prime by contract
  Show(2);   // boundary: smallest prime, the loop body never runs
  Show(13);  // prime: every candidate 2..12 is tried
  Show(21);  // composite: stops at 3 after two iterations
}
