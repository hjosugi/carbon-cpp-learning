# Carbon構文ハンズオン

## Lab 0: 最小プログラム

対象: `hands-on/carbon/nightly-smoke/00_hello.carbon`

```carbon
import Core library "io";

fn Run() {
  Core.Print(42);
}
```

観察点:

- entry pointは`Run`。
- importはC++のtextual `#include`よりmoduleに近い。
- statementは`;`、blockは`{}`。

## Lab 1: function、let、var

`let`は再代入しないbinding、`var`は変更可能です。型は名前の後ろに書きます。

```carbon
fn Double(value: i32) -> i32 {
  return value * 2;
}
```

課題:

1. `Clamp(value, low, high)`を実装する。
2. `let`を再代入してcompiler diagnosticを読む。
3. lossy conversionに`as`が必要な理由を説明する。

## Lab 2: control flowとtuple

`hands-on/carbon/nightly-smoke/03_tuple.carbon`を実行し、戻り値`(i32, bool)`の`.0`と`.1`を表示します。

課題:

- `n <= 1`をどう扱うかcontractを決める。
- loop回数を返す3要素tupleへ変える。
- 同じAPIをnamed struct resultにすると読みやすくなる場面を説明する。

Lab 1とLab 2の解答例は`hands-on/carbon/solutions/`にあり、`./scripts/run-carbon-katas.sh`が期待outputとcompiler diagnosticを検証します。結果は[basic syntax katas evidence](evidence/basic-syntax-katas.md)を参照してください。

## Lab 3: classとvalue semantics

`design-labs/04_counter.carbon`を読み、次をC++ classと比較します。

- field orderとlayout
- explicit initialization
- method receiver
- copy/moveの意味

このlabはdesign documentの学習用です。nightlyの実装状況によってはcompileできません。

pinned nightlyで動く版とC++23版は`hands-on/carbon/comparisons/counter_*.carbon`と`hands-on/cpp/counter/`にあり、`./scripts/run-carbon-comparisons.sh`と`make -C hands-on/cpp test diagnostics`で検証します。比較表とownership/lifetimeの説明は[class/value semantics evidence](evidence/class-value-semantics.md)を参照してください。

## Lab 4: choiceとpattern matching

`choice`はclosed setのsum typeです。C++では`std::variant`に相当する問題を、言語レベルのalternativeと`match`で表現します。

課題:

- `ParseResult(T)`を`Ok(T)`/`Error(code)`で設計する。
- errorをexceptionではなくvalueにする利点を説明する。
- exhaustive matchがAPI evolutionに与えるtradeoffを考える。

## Lab 5: checked generics

Carbonのchecked genericはdefinitionを一度type-checkし、interfaceをcontractとして使います。C++ templateのinstantiation時diagnosticと対比します。

課題:

- `Min[T: Ordered](a: T, b: T) -> T`を設計する。
- interfaceにないoperationをbodyで使うと、なぜdefinition側でerrorになるべきか説明する。
- specializationとbinary sizeのtradeoffを調べる。

## Lab 6: package/API/implementation

Carbon libraryは1つのAPI fileと0個以上のimplementation fileで構成されます。

- API: `package Geometry library "Shapes";`
- implementation: `impl package Geometry library "Shapes";`
- implementation file suffix: `.impl.carbon`
- API entityはdefault public、`private`でlibrary内に制限

課題:

- LogLensを`Parsing`, `Aggregation`, `Reporting`のlibraryに分割する。
- transitive API importsを最小化する。
- C++ header/source分離よりbuild dependencyを明示しやすい理由を説明する。

## 自己確認

- [ ] `let`と`var`を説明できる
- [ ] tupleとstruct resultの選択基準を言える
- [ ] checked genericとC++ templateのdiagnostic差を言える
- [ ] `choice`と`std::variant`を比較できる
- [ ] API/implementation fileの役割を言える
- [ ] design済みとtoolchain実装済みを区別できる
