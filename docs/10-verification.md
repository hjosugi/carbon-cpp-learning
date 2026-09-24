# 検証結果

検証日: 2026-07-12

## このbundleで実行済み

Environment（最終release環境）:

```text
g++ (GCC) 16.1.1 20260625
clang version 22.1.8
```

Passed:

- C++23 warnings with `-Werror`
- GitHub runnerのClang 18では`Result<T, E>` compatibility pathも検証
- parser/aggregation/histogram unit tests
- CLI integration tests（exit 0/2/3/4/5、stdin、limits）
- release build with `-O3 -DNDEBUG`
- sample file end-to-end execution
- AddressSanitizer
- UndefinedBehaviorSanitizer
- libFuzzer 10,000 runs
- libFuzzer 10-minute local run（109,738,844 runs / 601 seconds）
- scheduled/manual libFuzzer 10-minute workflowとcorpus artifact保存設定
- deterministic 100,000-line benchmark smoke
- 1,000,000-line peak RSS/CPU evidence（1 / 1,000 / 100,000 services）とregression threshold
- 100,000,000-line soak（bounded RSS、[benchmark report](evidence/benchmark-report.md)）
- shell syntax checks
- release archive、SPDX SBOM、provenance、SHA-256

Command:

```bash
./scripts/verify.sh
make -C product/loglens CXX=clang++ fuzz
make -C product/loglens benchmark
./scripts/package-release.sh
```

Expected summary from sample:

```json
{
  "accepted": 5,
  "malformed": 1
}
```

実際のreportにはservice別statsも含まれます。

## 公式情報で存在確認済み

- Carbon nightly `v0.0.0-0.nightly.2026.07.11`
- `carbon compile` / `carbon link` getting-started commands
- Carbon Compiler Explorer
- `actions/checkout@v7`（latest major、2026-06-18 release）

## Carbon smoke

公式asset digestを照合したpinned nightlyをdownloadし、4本すべてで`compile`、`link`、実行まで確認しています。Carbonはpre-0.1なので、nightly更新時には必ず再検証してください。design labsは意図的にtoolchain-supported保証の対象外です。

Carbon histogram port（`BucketFor` / `BucketUpper`）は全bucket境界の100 vectorsと、seed 20260925の10,000 random vectorsでC++ oracleとbyte一致します（[port evidence](evidence/carbon-histogram.md)、[differential evidence](evidence/carbon-differential.md)、`./scripts/run-carbon-differential.sh`）。CIの`Carbon labs (pinned nightly)` jobが`./scripts/check-carbon.sh`でCarbon checkをすべて実行します。
