# Carbon labs

## Nightly smoke

`nightly-smoke/`はpinned nightlyでcompile/link/runする最小例です。

```bash
../../scripts/bootstrap-carbon.sh
../../scripts/run-carbon-smoke.sh
```

各fileを次の順で変更してください。

1. `00_hello`: outputを変更し、compileとlinkを分けて実行する。
2. `01_functions`: `Clamp`を追加し、boundary testをprintする。
3. `02_control_flow`: `SumTo(0)`, `SumTo(10)`を試す。
4. `03_tuple`: tupleを3要素にし、loop countを追加する。

## Design labs

`design-labs/`は公式designを読むための例です。nightly未実装またはsyntax driftによりcompileできない場合があります。

学習手順:

1. fileを読む。
2. 期待するtype contractを日本語で書く。
3. Compiler Explorerで試す。
4. errorが実装不足かsyntax変更かを公式docs/releaseで切り分ける。
5. C++23で同じcontractを実装する。

`solutions/`は考え方の例です。先に見ず、自分のAPIを設計してください。

## Kata solutions

`solutions/`にはnightly smokeの課題2と4（Issue 004）の解答例と、lossy `as` conversionのkataがあります。pinned nightlyで検証できます。

```bash
../../scripts/run-carbon-katas.sh
```

- `NAME.carbon`: compile/link/runし、stdoutを`NAME.expected`と比較する。
- `expect-error/NAME.carbon`: check phaseでrejectされ、`NAME.expected-error`のdiagnosticを出すことを確認する。

実行結果と`let`/`var`、tuple/struct、`as`の説明は[basic syntax katas evidence](../../docs/evidence/basic-syntax-katas.md)にあります。

## C++ comparison labs

`comparisons/`はC++23版（`hands-on/cpp/`）と対になるCarbon版です。pinned nightlyで動く部分は実行し、未実装のdesign部分は`expect-error/`で正確なdiagnosticを固定します。

```bash
../../scripts/run-carbon-comparisons.sh
```

| Topic | Evidence |
| --- | --- |
| class/value semantics（Issue 005） | [class/value semantics evidence](../../docs/evidence/class-value-semantics.md) |
| checked generics（Issue 006） | [checked generics evidence](../../docs/evidence/checked-generics.md) |
