// Expected to fail in the parse phase: the `return` statement has no `;`.
package PipelineTrace;

fn MissingSemi(x: i32) -> i32 {
  return x + 1
}
