# v1.1.0 — Carbon × Modern C++ hands-on lab

v1.0.0のbaselineに、benchmark/soak gate、Carbon→C++ C ABI experiment、basic syntax katas、toolchain pipeline traceを追加したreleaseです。pinned Carbon nightlyは`0.0.0-0.nightly.2026.07.11`のままです。

## Highlights

- LogLens benchmark matrix: 1M行×1 / 1,000 / 100,000 servicesを毎PR測定し、peak RSSとCPU timeのregression thresholdで判定
- 週次100M行soak workflow。100M行でもpeak RSSは1M行と同じ（bounded memory）
- perf profileとflamegraphによるhot path説明（1文字ずつの`std::istream::get()`とservice lookup）
- pinned nightlyのCarbon executableがshared library経由でC++ `loglens_bucket_upper`を呼び、0/1/31/32 bucketとsymbol/calling conventionを検証
- 期待出力と期待diagnosticで検証するbasic syntax kata解答例（`Clamp`、tuple/struct result、lossy `as`）
- `a + b`をtokenからobject fileまで追跡したpipeline traceと、lex/parse/check errorのowner phase確認
- LogLens 1.1.0 Linux x86_64 binary、SHA256SUMS、provenance、SPDX 2.3 SBOM

## Verification

- CI: GCC/Clang、unit/integration、ASan/UBSan、parser fuzz smoke、reproducible package、benchmark regression gate
- Carbon labs（`run-carbon-smoke.sh`、`run-carbon-katas.sh`、`run-c-abi-experiment.sh`、`run-carbon-pipeline-trace.sh`）はpinned nightlyでlocal実行して確認（CIはCarbon toolchainをinstallしません）

## Important status

Carbonはpre-0.1の実験的プロジェクトで、本番利用向けではありません。製品baselineは実行検証済みのC++23版で、Carbonコードはnightly smoke、kata、interop experimentに分離しています。
