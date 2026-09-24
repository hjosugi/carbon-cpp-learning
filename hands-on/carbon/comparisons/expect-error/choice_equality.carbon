// Expected to fail in the check phase: a choice without parameters can be
// declared and created on the pinned nightly, but it has no `==` and no
// `match`, so there is no way to branch on it yet. parse_result.carbon uses
// an i32 code as the tag instead.
choice ParseErrorCode {
  Empty,
  NotDigit,
  Overflow
}

fn IsEmpty(code: ParseErrorCode) -> bool {
  return code == ParseErrorCode.Empty;
}
