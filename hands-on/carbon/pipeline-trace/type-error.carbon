// Expected to fail in the check phase: the source parses, but an f64 value
// cannot be implicitly converted to the i32 return type.
package PipelineTrace;

fn WrongReturnType() -> i32 {
  var x: f64 = 1.5;
  return x;
}
