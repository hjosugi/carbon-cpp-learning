# C++/Carbon differential test evidence

検証日: 2026-09-25

| Item | Value |
| --- | --- |
| Carbon | `0.0.0-0.nightly.2026.07.11+8be274c`（`.carbon-version` / `.carbon-sha256`で固定） |
| C++ compiler | `g++ (GCC) 16.2.1 20260810`（oracleをclang 22.1.8でbuildしてもvector hashは同じ） |
| Platform | Linux x86_64 |
| Script | [`run-carbon-differential.sh`](../../scripts/run-carbon-differential.sh) |
| C++ oracle | [`histogram_oracle.cpp`](../../product/loglens/tests/histogram_oracle.cpp) |
| Carbon port | [`histogram.carbon`](../../product/loglens/carbon_experiments/histogram.carbon)（[port evidence](carbon-histogram.md)） |
| CI | `ci` workflowの`Carbon labs (pinned nightly)` job（`./scripts/check-carbon.sh`） |

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-differential.sh                    # seed 20260925, 10,000 vectors
./scripts/run-carbon-differential.sh --seed 7 --count 100000
./scripts/check-carbon.sh                               # every Carbon check, as CI runs it
```

`CARBON_VERSION=<nightly>`を付けると、別のnightly（`bootstrap-carbon.sh`で同じ`CARBON_VERSION`をinstall済み）で同じcheckを実行します。nightly更新時はCIの`Carbon labs` jobが新しい`.carbon-version`で同じscriptを自動実行します。

## Shared vector file format (v1)

C++ oracleとCarbon portは同じtext fileを読みます（定義は`histogram_oracle.cpp`冒頭のcommentと[port evidence](carbon-histogram.md#vector-file-format-v1)）。

```text
# loglens histogram vectors v1
# random: generator=splitmix64 seed=20260925 count=10000
L <latency_ms>   ->  L <latency_ms> <bucket> <bucket_upper>
B <bucket>       ->  B <bucket> <bucket_upper>
```

入力1 vectorにつき出力1行なので、出力のN行目は入力のN番目のvectorに対応します。mismatchの行番号からvectorを特定できるのはこの性質のためです。

## Deterministic random vectors

`histogram_oracle random SEED COUNT`は[SplitMix64](https://prng.di.unimi.it/splitmix64.c)で生成します。整数演算（mod 2^64）だけで定義されるので、`<random>`のdistributionと違いcompilerやstandard libraryに依存しません。

| Vector | Probability | Value |
| --- | --- | --- |
| `L` | 3/4 | bucket 0..32を一様に選び、そのbucket内の値を一様に選ぶ |
| `B` | 1/4 × 7/8 | 0..39（境界とsaturation） |
| `B` | 1/4 × 1/8 | 任意の`u32` |

一様な`u32`だと半分がbucket 32に入るため、先にbucketを選びます。seed 20260925、10,000 vectorsの内訳は`L` 7,526（bucket 0..32にそれぞれ約230）、`B` 2,474（うち39超は313）でした。

決定性の確認:

- SplitMix64 seed 0の最初の出力が参照値`0xe220a8397b1dcdaf`と一致。
- 同じ生成規則をPythonで書き直したvector fileと、g++ / clang++でbuildしたoracleの出力が同じSHA-256（`1bcf9202...a133`）。

## Compare log

`build/carbon-differential/compare.log`（CIではartifact `carbon-differential`）:

```text
carbon: Carbon Language toolchain version: 0.0.0-0.nightly.2026.07.11+8be274c
cxx: g++ (GCC) 16.2.1 20260810
carbon_source: product/loglens/carbon_experiments/histogram.carbon
seed: 20260925
count: 10000
boundary vectors sha256: 4515d4e3c3418e81e99939f67e9ae68c679906b8311caa421e4461bca7408d1d
ok boundary: lines=100 exit=0 identical_bytes=1546
random vectors sha256: 1bcf920272ee551ddf747afd6856078a0fc39dba5ce974b9111c149b7015a133
ok random: lines=10000 exit=0 identical_bytes=162519
random output sha256: C++ 01f6839721b2be70d3ec3fd669dd18576bf2781cd9c13595e7bb1e89f4725911 Carbon 01f6839721b2be70d3ec3fd669dd18576bf2781cd9c13595e7bb1e89f4725911
ok leading-zeros: lines=2 exit=0 identical_bytes=16
ok malformed/unknown-tag: lines=3 exit=2 identical_bytes=8
...
ok malformed/u32-overflow: lines=1 exit=2 identical_bytes=0
ok shift_distance: rejected with the expected diagnostic
C++/Carbon differential test passed.
```

10,000 random vectorsの出力162,519 bytesがbyte単位で一致し、exit codeも一致しました。

## Mismatch shrinking

stdoutが違うと、scriptは`cmp`で最初の違う行を求め、その行のvectorを1行のminimal reproductionへ縮小します。候補は`0`、その値以下の最大の2の冪（`L`ではbucketの下端）、半分、1小さい値で、C++とCarbonがまだ食い違う最小の候補へ進み、どれも食い違わなくなったら止まります。結果は`build/carbon-differential/<set>.minimal.vectors`です。

negative control: `BucketUpper`の`bucket >= 32`を`bucket >= 31`に変えたcopyを`CARBON_DIFF_SOURCE`で与えると、次のように失敗します（exit 1）。

```text
$ CARBON_DIFF_SOURCE=build/negative/histogram_bucket31.carbon ./scripts/run-carbon-differential.sh
FAIL boundary: stdout differs (C++ exit 0, Carbon exit 0)
shrink boundary: first mismatch at vector 61: L 1073741824
minimal reproduction (build/carbon-differential/boundary.minimal.vectors): L 1073741824
  C++:    L 1073741824 31 2147483647
  Carbon: L 1073741824 31 4294967295
FAIL boundary: Carbon output differs from tests/golden/histogram-boundary.txt
FAIL random: stdout differs (C++ exit 0, Carbon exit 0)
shrink random: first mismatch at vector 14: L 1556827590
minimal reproduction (build/carbon-differential/random.minimal.vectors): L 1073741824
  C++:    L 1073741824 31 2147483647
  Carbon: L 1073741824 31 4294967295
3 differential check(s) failed.
```

random setで最初に食い違った`L 1556827590`が、壊したbucket 31の下端`2^30 = 1073741824`まで縮小されています。

## Scope

- 比較対象はhistogram coreのpure function（`bucket_for` / `bucket_upper`）です。parserやaggregation全体のCarbon portはまだありません。
- Carbon portはpinned nightly向けの実験で、製品binaryのdependencyではありません。`Carbon labs` jobはrequired checkではなく、nightly driftを検出するためのjobです。
