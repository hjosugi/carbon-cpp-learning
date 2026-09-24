# Carbon ↔ C++相互運用

## 現在の原則

1. C++ headerを`import Cpp library "..."`で読む。
2. imported namesは`Cpp` package下に置く。
3. primitive/common typeはzero-overhead mappingを目標にする。
4. C++ typeを含むCarbon typeにもC++ semanticsが波及する。
5. native Carbon toolchainと既存C++ toolchain混在の両方を目標にする。

## 最小experiment

```cpp
// metrics.h
#pragma once
#include <cstdint>

extern "C" std::uint64_t loglens_bucket_upper(std::uint32_t bucket) noexcept;
```

```carbon
import Cpp library "metrics.h";
import Core library "io";

fn Run() {
  let upper: u64 = Cpp.loglens_bucket_upper(10);
  Core.Print(upper);
}
```

`extern "C"`は教材側のABI実験を小さくするための選択です。Carbonの最終C++ interop能力をC ABIに限定する意味ではありません。

上のsnippetは設計sketchです。pinned nightlyの`Core.Print`は`i32`しか受け付けないため、`u64`はそのままprintできません。pinned nightlyでcompile/link/runを確認した版は[`c_abi_call.carbon`](../product/loglens/carbon_experiments/c_abi_call.carbon)で、`./scripts/run-c-abi-experiment.sh`がbuild、`nm`、calling convention、0/1/31/32 bucketを検証します。証跡は[C ABI experiment evidence](evidence/c-abi-experiment.md)にあります。

Phase 3の最初の一歩として、histogram core（`bucket_for` / `bucket_upper`）をCarbonへportしました。[`histogram.carbon`](../product/loglens/carbon_experiments/histogram.carbon)はC ABIを経由せず同じcontractをCarbonで実装し、`./scripts/run-carbon-differential.sh`がC++ oracleとbyte単位で比較します。shift/overflow boundaryと比較結果は[Carbon histogram port evidence](evidence/carbon-histogram.md)にあります。

## Boundary checklist

- ownership: caller/calleeのどちらがallocate/freeするか
- lifetime: borrowed pointer/viewの有効期間
- nullability: nullを許すか
- exceptions: language boundaryを越えさせない
- errors: status/resultを明示する
- ABI: integer width、alignment、calling convention
- strings: encoding、length、NUL termination
- concurrency: thread safetyとcallback thread
- versioning: struct size、symbol、feature negotiation
- tests: both directions、invalid input、sanitizer

## 段階移行

```text
Phase 1: C++製品 + Carbon smoke test
Phase 2: pure functionをC ABIでCarbonから呼ぶ
Phase 3: Carbon aggregation coreを実験実装
Phase 4: supported non-template C++ APIをCarbonから直接利用
Phase 5: toolchain/ABI/standard library成熟後にproduction判断
```

各phaseにrollback pathを持たせ、Carbon componentをfeature flagで無効化できるようにします。
