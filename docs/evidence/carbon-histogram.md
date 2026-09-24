# Carbon histogram port evidence

検証日: 2026-09-25

| Item | Value |
| --- | --- |
| Carbon | `0.0.0-0.nightly.2026.07.11+8be274c`（`.carbon-version` / `.carbon-sha256`で固定） |
| C++ compiler | `g++ (GCC) 16.2.1 20260810`（`make CXX=clang++`、clang 22.1.8でも同じgolden） |
| Platform | Linux x86_64 |
| Carbon source | [`histogram.carbon`](../../product/loglens/carbon_experiments/histogram.carbon) |
| C++ reference | [`aggregator.hpp`](../../product/loglens/include/loglens/aggregator.hpp)の`LatencyHistogram::bucket_for` / `bucket_upper` |
| C++ oracle | [`histogram_oracle.cpp`](../../product/loglens/tests/histogram_oracle.cpp) |
| Compare script | [`run-carbon-differential.sh`](../../scripts/run-carbon-differential.sh) |

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-differential.sh
```

C++側だけなら`make -C product/loglens test`が、oracleのboundary出力を[`histogram-boundary.txt`](../../product/loglens/tests/golden/histogram-boundary.txt)と比較します（CIのGCC/Clang jobで実行）。

## Ported functions

| C++ (`LatencyHistogram`) | Carbon | Contract |
| --- | --- | --- |
| `bucket_for(std::uint32_t) -> std::size_t`（`std::bit_width`） | `BucketFor(latency_ms: u32) -> u32` | 有効bit数。0→0、`2^(n-1)..2^n-1`→n。結果は0..32 |
| `bucket_upper(std::size_t) -> std::uint64_t` | `BucketUpper(bucket: u32) -> u64` | 0→0、1..31→`2^n-1`、32以上→`UINT32_MAX`へsaturate |

C++の`LatencyHistogram::add`は以前`std::bit_width`をinlineで使っていました。比較対象を明確にするため、pure functionの`bucket_for`として切り出し、`add`もそれを使います。

## Overflow and shift boundary

| Boundary | C++ | Carbon (pinned nightly) | Port contract |
| --- | --- | --- | --- |
| shift distance | `std::uint64_t{1} << bucket`はdistance >= 64でundefined behavior | constant distance >= 64はcheck phase error。run-time distanceはguardなしのLLVM `shl`（distance >= 64はpoison） | `bucket >= 32`を先にsaturateし、shiftは常に1..31 |
| `2^n - 1` | `std::uint64_t`で計算し、最大`2^31 - 1` | `u64`で計算 | bucket 1..31の上限は`u64`に余裕で収まる |
| bucket 32 | `UINT32_MAX`（`2^32 - 1`） | `4294967295` literal | saturation値は`u32`最大値で、両言語同じ |
| bit width loop | `std::bit_width`（loopなし） | `rest >> 1`を最大32回 | `u32`の右shiftだけでoverflowしない |
| vector parse | `std::from_chars`が`result_out_of_range` | `u64` accumulatorを1桁ごとに`u32`最大値と比較 | `4294967296`以上はmalformed（exit 2） |

constant shiftのdiagnostic（[`shift_distance.carbon`](../../product/loglens/carbon_experiments/expect-error/shift_distance.carbon)、scriptが毎回確認）:

```text
$ carbon compile --phase=check product/loglens/carbon_experiments/expect-error/shift_distance.carbon
product/loglens/carbon_experiments/expect-error/shift_distance.carbon:6:10: error: shift distance >= type width of 64 in `1 << 64`
  return (1 as u64) << (64 as u64);
         ^~~~~~~~~~~~~~~~~~~~~~~~~
```

run-time distanceにはcheckがありません。`fn Shift(amount: u64) -> u64 { return (1 as u64) << amount; }`は`shl i64 1, %amount`へ下がり、`Shift(64) as i32`はpinned nightlyで`-1482230144`のような不定値をprintしました。そのため`BucketUpper`はshiftの前にguardします。lowered IR（`--phase=lower --dump-llvm-ir`、`!dbg`を省略）:

```llvm
define i64 @_CBucketUpper.Main(i32 %bucket) #0 {
entry:
  %UInt.as.EqWith.impl.Equal.call = icmp eq i32 %bucket, 0
  br i1 %UInt.as.EqWith.impl.Equal.call, label %if.then.loc33, label %if.else.loc33
if.then.loc33:
  ret i64 0
if.else.loc33:
  %UInt.as.OrderedWith.impl.GreaterOrEquivalent.call = icmp uge i32 %bucket, 32
  br i1 %UInt.as.OrderedWith.impl.GreaterOrEquivalent.call, label %if.then.loc36, label %if.else.loc36
if.then.loc36:
  ret i64 4294967295
if.else.loc36:
  %UInt.as.As.impl.Convert.call = zext i32 %bucket to i64
  %UInt.as.LeftShiftWith.impl.Op.call = shl i64 1, %UInt.as.As.impl.Convert.call
  %UInt.as.SubWith.impl.Op.call = sub i64 %UInt.as.LeftShiftWith.impl.Op.call, 1
  ret i64 %UInt.as.SubWith.impl.Op.call
}
```

`shl`に届くのは`icmp uge i32 %bucket, 32`がfalseの場合だけなので、distanceは1..31です。

## Unsupported library features avoided

Carbon版はpinned nightlyのbuiltinである`Core.ReadChar`（`= "read.char"`）と`Core.PrintChar`（`= "print.char"`）だけを使います。

| Avoided | Reason on the pinned nightly | Used instead |
| --- | --- | --- |
| `Core.Print(u64)` | `Core.Print`は`i32`だけを受け付ける | `PrintU64`が`Core.PrintChar`で10進数字を1文字ずつ出力 |
| `Core.EOF()` | `core/io.carbon`のCarbon関数でbuiltinではない。`--output-last-input-only`ではCore側objectが出力されず、link時に`ld.lld: error: undefined symbol: _CEOF.Core` | `-1`と比較（`Core.ReadChar`はinput終端で-1を返す） |
| `c == 'L'`（`i32`とchar literalの比較） | ``cannot access member of interface `Core.EqWith(Core.CharLiteral)` in type `i32` that does not implement that interface``。`c == 'L' as i32`は`parentheses are required to disambiguate operator precedence` | `fn Code(c: char) -> i32 { return (c as u8) as i32; }`で明示変換（`('L' as i32)`もcompileする） |
| file I/O、container、string parse | Core libraryにない | stdinを1 byteずつ読むstate machine |

## Vector file format (v1)

C++ oracleとCarbon版は同じtext formatを読みます。1行1 vectorで、すべての行は`\n`で終わります。

| Input line | Output line |
| --- | --- |
| `# text` | なし（comment） |
| `L <latency_ms>` | `L <latency_ms> <bucket> <bucket_upper>` |
| `B <bucket>` | `B <bucket> <bucket_upper>` |

数値は0..`UINT32_MAX`の10進数です（leading zeroは受け付け、出力はcanonical）。最初のmalformed行でexit 2になり、それまでの行の結果はすでに出力済みです。この挙動も両言語で一致させています。

## Boundary cases

`histogram_oracle boundary`は`LatencyHistogram`を使わずに境界を生成します。

- latency: 0、各bucket n = 1..32の下端`2^(n-1)`と上端`2^n-1`（n = 1は1つ）。隣接bucketの上端と下端が必ず並ぶので、すべてのbucket境界の両側を通ります（64 vectors）。
- bucket upper: bucket 0..33、64、`UINT32_MAX`（saturationと範囲外、36 vectors）。

32-bit入力空間でbucketが変わる点はこの64値ですべてです。

```text
L 0 0 0
L 1 1 1
L 2 2 3
L 3 2 3
L 4 3 7
...
L 1073741824 31 2147483647
L 2147483647 31 2147483647
L 2147483648 32 4294967295
L 4294967295 32 4294967295
B 0 0
B 1 1
...
B 31 2147483647
B 32 4294967295
B 33 4294967295
B 64 4294967295
B 4294967295 4294967295
```

vector fileのSHA-256は`4515d4e3c3418e81e99939f67e9ae68c679906b8311caa421e4461bca7408d1d`、golden outputは`5d3261650f98c1e24f2c5265dc251a7cc24b57ed035af3f92db40f770186a257`です。

## Comparison output

```text
$ ./scripts/run-carbon-differential.sh
Carbon Language toolchain version: 0.0.0-0.nightly.2026.07.11+8be274c
==> Build the C++ oracle
make: 'build/test/histogram_oracle' is up to date.
==> Compile and link the Carbon port
==> Boundary vectors
ok boundary: lines=100 exit=0 identical_bytes=1546
==> Accepted edge input
ok leading-zeros: lines=2 exit=0 identical_bytes=16
==> Malformed input (both must stop with exit 2 after the same prefix)
ok malformed/unknown-tag: lines=3 exit=2 identical_bytes=8
ok malformed/missing-newline: lines=2 exit=2 identical_bytes=8
ok malformed/comment-without-newline: lines=1 exit=2 identical_bytes=8
ok malformed/empty-line: lines=3 exit=2 identical_bytes=8
ok malformed/crlf: lines=1 exit=2 identical_bytes=0
ok malformed/empty-number: lines=1 exit=2 identical_bytes=0
ok malformed/double-space: lines=1 exit=2 identical_bytes=0
ok malformed/negative: lines=1 exit=2 identical_bytes=0
ok malformed/trailing-garbage: lines=1 exit=2 identical_bytes=0
ok malformed/u32-overflow: lines=1 exit=2 identical_bytes=0
==> Constant shift distance >= width is rejected in the check phase
product/loglens/carbon_experiments/expect-error/shift_distance.carbon:6:10: error: shift distance >= type width of 64 in `1 << 64`
C++/Carbon differential test passed.
```

scriptはstdoutの`cmp`とexit codeの一致を要求し、Carbon出力をgoldenとも比較します。negative controlとして`BucketUpper`の`bucket >= 32`を`bucket >= 31`へ変えると、`boundary: stdout differs`とgolden mismatchの2件でexit 1になることを確認しました。

## Scope

- Carbonはpre-0.1のため、このportはpinned nightlyだけを対象にし、製品のbuild/runtime dependencyにはしません（[readiness review](../11-readiness-review.md)）。
- Carbon side dataは`u32`/`u64`だけで、C ABI（[C ABI experiment](c-abi-experiment.md)）と同じfixed-width contractです。
