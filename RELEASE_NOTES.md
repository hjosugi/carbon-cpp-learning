# v1.2.0 — Carbon × Modern C++ hands-on lab

v1.1.0に、histogram coreのCarbon port、C++/Carbon differential test、CIでのCarbon check、Carbon nightly更新の自動検証、`Counter`のclass/value semantics比較を追加したreleaseです。pinned Carbon nightlyは`0.0.0-0.nightly.2026.07.11`のままです。

## Highlights

- histogram coreのCarbon port: `BucketFor(u32) -> u32`と`BucketUpper(u32) -> u64`が、C++の`bucket_for` / `bucket_upper`と全bucket境界の100 vectorsでbyte一致。shift distanceは常に1..31で、constant shift >= 64のcheck-phase diagnosticも毎回確認
- C++/Carbon differential test: SplitMix64による10,000 vectors（seed 20260925）、vector/output SHA-256のcompare log、mismatchを1行のminimal reproductionへ縮小
- CIの`Carbon labs (pinned nightly)` job: pinned nightlyをSHA-256照合してinstallし、smoke、kata、pipeline trace、C ABI、比較lab、differential testをすべて実行
- `carbon-nightly` workflow: 最新nightlyの発見とasset確認を分け、すべてのCarbon checkを通った候補だけを1本のproposal branchで提案（release notes summary付き、mergeはしない、`GITHUB_TOKEN`のみ）。手順とrollbackは`docs/13-carbon-nightly-refresh.md`
- `Counter` value typeのCarbon/C++23比較: field order、initialization、copy、move、borrow、destroyを期待出力と期待diagnosticで検証
- LogLens 1.2.0 Linux x86_64 binary、SHA256SUMS、provenance、SPDX 2.3 SBOM

## Verification

- CI: GCC/Clang、unit/integration（histogram oracle goldenを含む）、C++比較lab、ASan/UBSan、parser fuzz smoke、reproducible package、benchmark regression gate、Carbon labs（pinned nightly）
- 最新nightly `0.0.0-0.nightly.2026.09.24`でも`./scripts/check-carbon.sh`がすべて通ることをlocalで確認

## Important status

Carbonはpre-0.1の実験的プロジェクトで、本番利用向けではありません。製品baselineは実行検証済みのC++23版で、Carbonコードはnightly smoke、kata、比較lab、interop/port experimentに分離しています。
