# Carbon toolchain pipelineを追跡する

Labels: `area/carbon`, `type/learning`, `priority/p1`

Depends on: #003

## Tasks

- [x] Source/Lex/Parse/Check/Lower/CodeGenのinput/outputを説明する
- [x] pinned binaryの`carbon help`で利用可能dump optionを確認する
- [x] simple functionのParse Tree、SemIR、LLVM IRを追う
- [x] syntax errorとtype errorが異なるphaseで出ることを確認する

## Acceptance criteria

1つのsource constructをtokenからobjectまで追跡したnoteがあり、diagnostic owner phaseを説明できる。

## Evidence

toolchain version、help output、各dump、annotated pipeline図を保存する。

- [`docs/evidence/pipeline-trace.md`](../docs/evidence/pipeline-trace.md) — toolchain version、`carbon help` output、dump flag一覧、token/parse tree/SemIR/LLVM IR dump、syntax error/type error diagnostic、annotated pipeline図
- [`hands-on/carbon/pipeline-trace/add.carbon`](../hands-on/carbon/pipeline-trace/add.carbon) — 追跡用ソース（`fn Add(a: i32, b: i32) -> i32`）
- [`hands-on/carbon/pipeline-trace/syntax-error.carbon`](../hands-on/carbon/pipeline-trace/syntax-error.carbon) — Parse phase diagnostic例
- [`hands-on/carbon/pipeline-trace/type-error.carbon`](../hands-on/carbon/pipeline-trace/type-error.carbon) — Check phase diagnostic例
