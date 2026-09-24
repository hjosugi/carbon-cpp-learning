// Design-only: the move operator `~x` is provisional in docs/design/README.md
// ("Move") and is not parsed by the pinned nightly. Ownership moves into a
// `var` parameter from a temporary instead (see Finish in counter_value.carbon).
class Counter {
  var value: i32;
}

fn Move() -> i32 {
  var counter: Counter = {.value = 1};
  var moved: Counter = ~counter;
  return moved.value;
}
