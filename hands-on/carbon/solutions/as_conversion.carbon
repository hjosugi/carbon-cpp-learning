// Kata 4 (issue #4): explicit `as` conversion from i32 to i16.
// `let n: i16 = wide;` is rejected by the compiler (see
// expect-error/implicit_narrowing.carbon), so a narrowing conversion must be
// spelled with `as`, which keeps the low 16 bits.
import Core library "io";

fn Narrow(wide: i32) -> i16 {
  return wide as i16;
}

fn Run() {
  // Positive: the value fits in i16 and is unchanged.
  Core.Print(Narrow(100) as i32);    // 100
  Core.Print(Narrow(32767) as i32);  // 32767, i16 max: last value that fits
  // Negative: the value does not fit and wraps modulo 2^16.
  Core.Print(Narrow(32768) as i32);  // -32768 (32768 - 65536)
  Core.Print(Narrow(40000) as i32);  // -25536 (40000 - 65536)
}
