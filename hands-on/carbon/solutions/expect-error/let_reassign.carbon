// Expected to fail in the check phase: a `let` binding cannot be assigned.
import Core library "io";

fn Run() {
  let answer: i32 = 42;
  answer = 43;
  Core.Print(answer);
}
