# v1.3.0 — Carbon × Modern C++ hands-on lab

v1.2.0に、`choice`とerrors-as-valuesのCarbon/C++23比較を追加したreleaseです。pinned Carbon nightlyは`0.0.0-0.nightly.2026.07.11`のままです。

## Highlights

- invalid inputを通常eventとして扱うlatency parserを、同じerror contract（Empty / NotDigit / Overflow、最初のerrorを返す、1行1結果）でCarbonとC++23に実装
- Carbon: `choice ParseResult`と`match`はpinned nightlyで未実装（`choice alternatives with parameters are not yet supported`、`HandleMatchIntroducer`）のため、design-only fileのdiagnosticを毎回確認し、実行版はtagged classで同じcontractを検証
- C++23: `std::expected`版、`std::variant` + `std::visit`版、exception版を比較し、alternative追加時にvisitorや`switch`がcompile errorになることを期待diagnosticで確認
- exceptionを使わない理由と、使うべき場面をevidenceに記録
- LogLens 1.3.0 Linux x86_64 binary、SHA256SUMS、provenance、SPDX 2.3 SBOM（LogLens本体の変更はversion番号のみ）

## Verification

- CI: GCC/Clang、unit/integration、C++比較lab（test / diagnostics）、ASan/UBSan、parser fuzz smoke、reproducible package、benchmark regression gate、Carbon labs（pinned nightly）

## Important status

Carbonはpre-0.1の実験的プロジェクトで、本番利用向けではありません。製品baselineは実行検証済みのC++23版です。
