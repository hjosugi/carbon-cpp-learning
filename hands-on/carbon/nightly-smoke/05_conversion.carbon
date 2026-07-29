import Core library "io";

fn Run() {
  // as conversion is required whenever implicit conversion would be lossy.
  // let = immutable binding, var = mutable binding.

  // Positive example: value fits in i16; no data loss.
  var pos: i32 = 100;
  let pos16: i16 = pos as i16;
  Core.Print(pos16 as i32);  // 100

  // Negative example: value overflows i16; data is lost (wraps modulo 2^16).
  var neg: i32 = 40000;
  let neg16: i16 = neg as i16;
  Core.Print(neg16 as i32);  // -25536  (40000 - 65536)
}
