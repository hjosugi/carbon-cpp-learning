// Expected to fail in the lex phase: `G` is not a hexadecimal digit, so the
// lexer cannot form a numeric literal token.
package PipelineTrace;

fn BadLiteral() -> i32 {
  return 0x1G;
}
