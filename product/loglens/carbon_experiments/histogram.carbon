// Carbon port of the LogLens latency histogram core (issue #21).
//
// `BucketFor` and `BucketUpper` are pure functions that mirror
// `LatencyHistogram::bucket_for` and `LatencyHistogram::bucket_upper` in
// loglens/aggregator.hpp. `Run` evaluates a vector file read from stdin, in
// the format documented in tests/histogram_oracle.cpp, so that
// ./scripts/run-carbon-differential.sh can compare its stdout byte for byte
// with the C++ oracle.
//
// Verified against the pinned nightly only. The only library features used are
// the `Core.ReadChar` and `Core.PrintChar` builtins: no containers, no string
// formatting, and no `Core.EOF()`, which does not link with
// `--output-last-input-only` (see docs/evidence/carbon-histogram.md).
import Core library "io";

// Number of significant bits: 0 maps to bucket 0 and 2^(n-1)..2^n-1 map to
// bucket n, so the result is 0..32. The loop shifts right at most 32 times.
fn BucketFor(latency_ms: u32) -> u32 {
  var width: u32 = 0;
  var rest: u32 = latency_ms;
  while (rest != 0) {
    rest = rest >> 1;
    ++width;
  }
  return width;
}

// Inclusive upper edge of a bucket. Buckets >= 32 saturate at the u32 maximum
// before shifting, so the shift distance is always 1..31. The guard matters:
// a run-time shift by >= 64 lowers to an unchecked LLVM `shl` on the pinned
// nightly.
fn BucketUpper(bucket: u32) -> u64 {
  if (bucket == 0) {
    return 0;
  }
  if (bucket >= 32) {
    return 4294967295;
  }
  return ((1 as u64) << (bucket as u64)) - 1;
}

// `Core.ReadChar` returns one byte as i32, or -1 at the end of input.
fn Code(c: char) -> i32 {
  return (c as u8) as i32;
}

fn IsDigit(c: i32) -> bool {
  return c >= Code('0') and c <= Code('9');
}

// Reads "<decimal u32>\n", the rest of a vector line after "L " or "B ".
// `.ok` is false for an empty number, a non-digit, a missing newline, or a
// value above the u32 maximum. The u64 accumulator cannot overflow because
// it is checked against the u32 maximum after every digit.
fn ReadU32Line() -> {.ok: bool, .value: u32} {
  var value: u64 = 0;
  var digits: i32 = 0;
  var c: i32 = Core.ReadChar();
  while (IsDigit(c)) {
    value = value * 10 + ((c - Code('0')) as u64);
    if (value > 4294967295) {
      return {.ok = false, .value = 0};
    }
    ++digits;
    c = Core.ReadChar();
  }
  if (digits == 0 or c != Code('\n')) {
    return {.ok = false, .value = 0};
  }
  return {.ok = true, .value = value as u32};
}

// `Core.Print` only accepts i32 in the pinned nightly, so print the decimal
// digits of a u64 one at a time.
fn PrintU64(value: u64) {
  let digits: str = "0123456789";
  if (value >= 10) {
    PrintU64(value / 10);
  }
  Core.PrintChar(digits[(value % 10) as i64]);
}

// "L <latency_ms> <bucket> <upper>"
fn PrintLatency(latency_ms: u32) {
  let bucket: u32 = BucketFor(latency_ms);
  Core.PrintChar('L');
  Core.PrintChar(' ');
  PrintU64(latency_ms as u64);
  Core.PrintChar(' ');
  PrintU64(bucket as u64);
  Core.PrintChar(' ');
  PrintU64(BucketUpper(bucket));
  Core.PrintChar('\n');
}

// "B <bucket> <upper>"
fn PrintBucket(bucket: u32) {
  Core.PrintChar('B');
  Core.PrintChar(' ');
  PrintU64(bucket as u64);
  Core.PrintChar(' ');
  PrintU64(BucketUpper(bucket));
  Core.PrintChar('\n');
}

// Exit code 0 when every line was evaluated, 2 at the first malformed line
// (the lines before it have already been printed, as in the C++ oracle).
fn Run() -> i32 {
  var c: i32 = Core.ReadChar();
  while (c != -1) {
    if (c == Code('#')) {
      // Comment: skip to the end of the line, which must end with '\n'.
      while (c != Code('\n')) {
        c = Core.ReadChar();
        if (c == -1) {
          return 2;
        }
      }
    } else if (c == Code('L') or c == Code('B')) {
      let tag: i32 = c;
      if (Core.ReadChar() != Code(' ')) {
        return 2;
      }
      let number: {.ok: bool, .value: u32} = ReadU32Line();
      if (not number.ok) {
        return 2;
      }
      if (tag == Code('L')) {
        PrintLatency(number.value);
      } else {
        PrintBucket(number.value);
      }
    } else {
      return 2;
    }
    c = Core.ReadChar();
  }
  return 0;
}
