// Check phase error example: return type mismatch
// Expected: error: cannot implicitly convert expression of type `f64` to `i32` [ConversionFailure]
// Carbon nightly: 0.0.0-0.nightly.2026.07.11

package TypeErrorExample api;

fn WrongReturnType() -> i32 {
  var x: f64 = 1.5;
  return x;
}
