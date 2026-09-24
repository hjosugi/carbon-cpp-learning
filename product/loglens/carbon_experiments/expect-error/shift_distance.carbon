// Must be rejected (issue #21): a constant shift distance >= the type width is
// a check-phase error. Only constant distances are checked; a run-time
// distance >= 64 compiles to an unchecked shift, which is why BucketUpper in
// ../histogram.carbon saturates buckets >= 32 before it shifts.
fn Overflow() -> u64 {
  return (1 as u64) << (64 as u64);
}
