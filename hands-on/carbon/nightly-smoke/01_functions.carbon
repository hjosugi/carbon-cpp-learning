import Core library "io";

fn Double(value: i32) -> i32 {
  return value * 2;
}

fn Run() {
  let answer: i32 = Double(21);
  Core.Print(answer);
}
