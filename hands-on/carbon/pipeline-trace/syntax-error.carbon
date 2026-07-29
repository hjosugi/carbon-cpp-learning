// Parse phase error example: missing semicolon after return statement
// Expected: error: expected `;` after `return` statement [ExpectedReturnSemi]
// Carbon nightly: 0.0.0-0.nightly.2026.07.11

package SyntaxErrorExample api;

fn MissingSemi(x: i32) -> i32 {
  return x + 1
}
