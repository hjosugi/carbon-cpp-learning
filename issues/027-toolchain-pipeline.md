# Carbon toolchain pipelineを追跡する

Labels: `area/carbon`, `type/learning`, `priority/p1`

Depends on: #003

## Tasks

- [ ] Source/Lex/Parse/Check/Lower/CodeGenのinput/outputを説明する
- [ ] pinned binaryの`carbon help`で利用可能dump optionを確認する
- [ ] simple functionのParse Tree、SemIR、LLVM IRを追う
- [ ] syntax errorとtype errorが異なるphaseで出ることを確認する

## Acceptance criteria

1つのsource constructをtokenからobjectまで追跡したnoteがあり、diagnostic owner phaseを説明できる。

## Evidence

toolchain version、help output、各dump、annotated pipeline図を保存する。
