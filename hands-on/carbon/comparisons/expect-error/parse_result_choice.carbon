// Design-only: the parse result as a choice type with a `match` over every
// alternative (docs/design/sum_types.md, docs/design/pattern_matching.md).
// The pinned nightly rejects choice alternatives with parameters and `match`
// statements, so parse_result.carbon uses a tagged class instead.
// Per the design, a `match` without `default` that misses an alternative is
// an error, so adding an alternative breaks every non-exhaustive `match`.
choice ParseResult {
  Ok(value: i32),
  Empty,
  NotDigit(position: i32),
  Overflow
}

fn Code(result: ParseResult) -> i32 {
  match (result) {
    case .Ok(value: i32) => { return 0; }
    case .Empty => { return 1; }
    case .NotDigit(position: i32) => { return 2; }
    case .Overflow => { return 3; }
  }
}
