// Issue #7: errors as values on the pinned nightly.
// C++ counterpart: hands-on/cpp/errors/parse_result.hpp and
// parse_result_test.cpp. Check: ./scripts/run-carbon-comparisons.sh, which
// feeds parse_result.input on stdin.
//
// The design models this result as a choice type with a `match` over every
// alternative (expect-error/parse_result_choice.carbon). The pinned nightly
// rejects choice alternatives with parameters and `match`, so this runnable
// version spells the sum type as a class: a tag (`code`) plus the payload.
import Core library "io";

// Error contract, one code per alternative. 0 means Ok.
//   1 Empty:    the line has no characters.
//   2 NotDigit: a character is not 0-9.
//   3 Overflow: the value does not fit in i32.
class ParseResult {
  var code: i32;
  var value: i32;

  fn Ok(value: i32) -> Self {
    return {.code = 0, .value = value};
  }

  fn Error(code: i32) -> Self {
    return {.code = code, .value = 0};
  }

  fn IsOk(self) -> bool {
    return self.code == 0;
  }
}

// `Core.ReadChar()` returns -1 at end of input. The literal is used because
// calling `Core.EOF()` fails to link on the pinned nightly
// (`ld.lld: error: undefined symbol: _CEOF.Core`).
fn EndOfInput() -> i32 {
  return -1;
}

// Reads one line from stdin and parses it as a latency in milliseconds.
// Invalid input is a normal event: every line produces a value, and the loop
// in Run keeps going after an error. `at_end` is set when no line was left;
// the caller marks the argument too: `ParseLine(ref at_end)`.
fn ParseLine(ref at_end: bool) -> ParseResult {
  var character: i32 = Core.ReadChar();
  if (character == EndOfInput()) {
    at_end = true;
    return ParseResult.Error(1);
  }
  var digits: i32 = 0;
  var total: i64 = 0;
  var code: i32 = 0;
  // Always consume the whole line, even after the first error.
  while (character != EndOfInput() and character != 10) {
    if (code == 0) {
      if (character < 48 or character > 57) {
        code = 2;
      } else {
        total = total * 10 + ((character - 48) as i64);
        ++digits;
        if (total > 2147483647) {
          code = 3;
        }
      }
    }
    character = Core.ReadChar();
  }
  if (code != 0) {
    return ParseResult.Error(code);
  }
  if (digits == 0) {
    return ParseResult.Error(1);
  }
  return ParseResult.Ok(total as i32);
}

// Prints the value for Ok and the negated code for an error.
fn Report(result: ParseResult) {
  if (result.IsOk()) {
    Core.Print(result.value);
  } else {
    Core.Print(-result.code);
  }
}

fn Run() {
  var at_end: bool = false;
  var result: ParseResult = ParseLine(ref at_end);
  while (not at_end) {
    Report(result);
    result = ParseLine(ref at_end);
  }
}
