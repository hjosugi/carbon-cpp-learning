# C ABI experimentを実装する

Labels: `area/interop`, `type/feature`, `priority/p1`, `risk/toolchain`

Depends on: #019

## Tasks

- [ ] C++ `bucket_upper`を`extern "C"`でexportする
- [ ] Carbonからheader importして呼ぶ
- [ ] boundary valuesを両言語でtestする
- [ ] symbol tableとcalling conventionを確認する

## Acceptance criteria

pinned nightlyでCarbon executableがC++ functionを呼び、0/1/31/32 bucketで期待値が一致する。

## Evidence

build commands、`nm` output、execution outputを保存する。
