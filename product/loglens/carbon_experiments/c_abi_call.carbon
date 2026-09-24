// C ABI interop experiment (issue #20): Carbon imports the `extern "C"` seam
// in loglens/c_api.h and calls the C++ implementation of
// `loglens_bucket_upper` for the boundary buckets 0 / 1 / 31 / 32.
//
// Verified against the pinned nightly only. Build, inspect and run it with:
//   ./scripts/run-c-abi-experiment.sh

import Cpp library "loglens/c_api.h";
import Core library "io";

// `Core.Print` only accepts `i32` in the pinned nightly, but the C ABI returns
// `uint64_t` (imported as `u64`), so print the decimal digits one at a time.
fn PrintU64(value: u64) {
  let digits: str = "0123456789";
  if (value >= 10) {
    PrintU64(value / 10);
  }
  Core.PrintChar(digits[(value % 10) as i64]);
}

// Prints "<bucket> <upper>" for one bucket.
fn PrintBucket(bucket: u32) {
  PrintU64(bucket as u64);
  Core.PrintChar(' ');
  PrintU64(Cpp.loglens_bucket_upper(bucket));
  Core.PrintChar('\n');
}

fn Run() {
  PrintBucket(0);
  PrintBucket(1);
  PrintBucket(31);
  PrintBucket(32);
}
