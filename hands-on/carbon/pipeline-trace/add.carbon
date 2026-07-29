// Pipeline trace source: simple Add function
// Used with: carbon compile --dump-tokens --dump-parse-tree --dump-sem-ir --dump-llvm-ir
// Carbon nightly: 0.0.0-0.nightly.2026.07.11

package PipelineTrace api;

fn Add(a: i32, b: i32) -> i32 {
  return a + b;
}
