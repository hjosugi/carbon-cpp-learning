// Expected to fail in the check phase: i32 -> i16 may lose data, so it is
// not an implicit conversion. as_conversion.carbon spells it with `as`.
import Core library "io";

fn Run() {
  var wide: i32 = 100;
  let narrow: i16 = wide;
  Core.Print(narrow as i32);
}
