# Checked generics / C++ concepts evidence

検証日: 2026-09-25

| Item | Value |
| --- | --- |
| Carbon | `0.0.0-0.nightly.2026.07.11+8be274c`（`.carbon-version` / `.carbon-sha256`で固定） |
| C++ compiler | `g++ (GCC) 16.2.1 20260810`、`clang version 22.1.8`（CIはUbuntu 24.04のGCC/Clangで`make test diagnostics`） |
| Platform | Linux x86_64 |
| Carbon sources | [`min_generic.carbon`](../../hands-on/carbon/comparisons/min_generic.carbon)、[`generic_specialization.carbon`](../../hands-on/carbon/comparisons/generic_specialization.carbon)、[`expect-error/min*.carbon`](../../hands-on/carbon/comparisons/expect-error/) |
| C++ sources | [`generics/min.hpp`](../../hands-on/cpp/generics/min.hpp)、[`generics/min_test.cpp`](../../hands-on/cpp/generics/min_test.cpp)、[`expect-error/min*.cpp`](../../hands-on/cpp/expect-error/) |
| Measurement | [`scripts/measure-generic-instantiations.sh`](../../scripts/measure-generic-instantiations.sh) |
| Design reference | [Generics overview](https://docs.carbon-lang.dev/docs/design/generics/overview.html)、[details "Overlap rule"](https://docs.carbon-lang.dev/docs/design/generics/details.html)（2026-09-25確認） |

Issue 006の`Min`を、Carbon interface付きchecked genericとC++23 conceptで書き、definition checkingとinstantiation checkingの違いを具体的なerrorで比べます。

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-comparisons.sh
make -C hands-on/cpp CXX=g++ test diagnostics
make -C hands-on/cpp CXX=clang++ test diagnostics
./scripts/measure-generic-instantiations.sh   # evidence only, not a CI gate
```

## Contract

| | Carbon | C++23 |
| --- | --- | --- |
| requirement | `interface Ordered { fn Less(self, other: Self) -> bool; }` | `concept Ordered = std::copyable<T> && requires { OrderedImpl<T>::less(a, b) } -> std::same_as<bool>` |
| opt-in | `impl i32 as Ordered`、`impl Version as Ordered`（自分のものでない`i32`にも書ける） | `OrderedImpl<std::int32_t>`、`OrderedImpl<Version>`のspecialization |
| generic | `fn Min[T: Ordered & Core.Copy](left: T, right: T) -> T` | `template <Ordered T> auto min_of(const T&, const T&) -> T` |
| 同値時 | `left`を返す（`std::min`と同じ） | 同じ |

C++版はCarbonのimplに合わせてtraits specializationでopt-inにしています。`static_assert(!Ordered<std::int64_t>)`のとおり、`operator<`を持つ型でも`OrderedImpl`がなければ満たしません。

## Execution output

```text
$ ./scripts/run-carbon-comparisons.sh
==> generic_specialization
1
2
2
==> min_generic
2
-1
1
2
7
...
Carbon comparison labs passed.

$ make -C hands-on/cpp CXX=g++ test
==> build/g++/counter/counter_test
counter_test: 9 tests passed
==> build/g++/generics/min_test
min_test: 5 tests passed
```

`min_generic`は`Min(3, 2)`、`Min(-1, -1)`、`Min(Version{1, 5}, Version{1, 2})`の`major`/`minor`、`Min3(7, 9, 8)`です。C++の`min_test`は同じ値を`CHECK`し、`min_of`は`constexpr`なので`static_assert`でもcompile時に確認します。

## Definition checking vs instantiation checking

### 1. bodyがcontract外のoperationを使う

同じbody（`right < left`）を両言語で書きます。`Ordered`は`Less`しか要求していません。

Carbonは**誰も呼んでいないのに**、generic definitionをcheckした時点でrejectします。

```text
$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/min_body_uses_less_than.carbon
hands-on/carbon/comparisons/expect-error/min_body_uses_less_than.carbon:11:7: error: cannot access member of interface `Core.OrderedWith(T)` in type `T` that does not implement that interface
  if (right < left) {
      ^~~~~~~~~~~~
```

C++の`min_body_outside_contract`は`template <Ordered T>`で制約されていても、bodyはconceptに照らしてcheckされません。definitionはcompileでき、`min_test`では`std::int32_t`（`operator<`を持つ）で呼んで**成功します**。`Ordered`を満たす`Version`で呼んだ時に初めて、template body内のerrorになります。

```text
$ g++ -std=c++23 ... -fsyntax-only expect-error/min_body_outside_contract.cpp
./generics/min.hpp: In instantiation of ‘constexpr T compare::min_body_outside_contract(const T&, const T&) [with T = Version]’:
expect-error/min_body_outside_contract.cpp:8:44:   required from here
./generics/min.hpp:73:16: error: no match for ‘operator<’ (operand types are ‘const compare::Version’ and ‘const compare::Version’)
   73 |   return right < left ? right : left;

$ clang++ -std=c++23 ... -fsyntax-only expect-error/min_body_outside_contract.cpp
./generics/min.hpp:73:16: error: invalid operands to binary expression ('const compare::Version' and 'const compare::Version')
expect-error/min_body_outside_contract.cpp:8:19: note: in instantiation of function template specialization 'compare::min_body_outside_contract<compare::Version>' requested here
```

errorはlibrary作者の`min.hpp:73`を指し、原因はcontractの書き漏れなのに、見つけるのは`Version`で呼んだ利用者です。制約のない`min_unconstrained`（`expect-error/min_unconstrained_body.cpp`）も同じdiagnosticになります。

### 2. 呼び出し側の型がcontractを満たさない

ここはconceptがあればC++もcall siteで止まります。

```text
$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/min_call_without_impl.carbon
hands-on/carbon/comparisons/expect-error/min_call_without_impl.carbon:28:10: error: cannot convert type `Unordered` into type implementing `Ordered & Core.Copy`
  return Min(first, second);
         ^~~~~~~~~~~~~~~~~~
hands-on/carbon/comparisons/expect-error/min_call_without_impl.carbon:18:1: note: while deducing parameters of generic declared here

$ clang++ -std=c++23 ... -fsyntax-only expect-error/min_constraint_not_satisfied.cpp
expect-error/min_constraint_not_satisfied.cpp:7:10: error: no matching function for call to 'min_of'
./generics/min.hpp:56:30: note: candidate template ignored: constraints not satisfied [with T = compare::Unordered]
./generics/min.hpp:55:11: note: because 'compare::Unordered' does not satisfy 'Ordered'
./generics/min.hpp:21:9: note: because 'OrderedImpl<T>::less(left, right)' would be invalid: implicit instantiation of undefined template 'compare::OrderedImpl<compare::Unordered>'
```

GCC 16.2.1は`error: no matching function for call to ‘min_of(compare::Unordered, compare::Unordered)’`と、nested noteの`constraints not satisfied`、`the required expression ‘compare::OrderedImpl<T>::less(left, right)’ is invalid`を出します。

### 3. Carbonはcontractに「copy」「destroy」も書かせる

Carbonのdefinition checkはbodyが`T`に対して行う**すべて**をcontractで説明させます。

```text
$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/min_missing_copy.carbon
hands-on/carbon/comparisons/expect-error/min_missing_copy.carbon:9:12: error: cannot copy value of type `T`
    return right;
           ^~~~~
hands-on/carbon/comparisons/expect-error/min_missing_copy.carbon:9:12: note: type `T` does not implement interface `Core.Copy`
...
hands-on/carbon/comparisons/expect-error/min_missing_copy.carbon:11:10: error: cannot copy value of type `T`

$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/min3_missing_destroy.carbon
hands-on/carbon/comparisons/expect-error/min3_missing_destroy.carbon:16:14: error: cannot access member of interface `Core.Destroy` in type `T` that does not implement that interface
  return Min(Min(a, b), c);
             ^~~~~~~~~
```

`Min(Min(a, b), c)`の内側の結果はtemporaryで、destroyが必要です。そのため`Min3`は`T: Ordered & Core.Copy & Core.Destroy`になります。C++では`std::copyable`が`std::destructible`を含み、そもそもbodyをconceptでcheckしないので、書き漏れてもerrorになりません。

### 4. integer literal

```text
$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/min_int_literal.carbon
hands-on/carbon/comparisons/expect-error/min_int_literal.carbon:22:10: error: cannot convert type `Core.IntLiteral` into type implementing `Ordered & Core.Copy`
  return Min(3, 2);
         ^~~~~~~~~
```

Carbonの`3`は`Core.IntLiteral`型で、`i32`ではありません。`Min(3 as i32, 2 as i32)`と書きます。C++の`3`は`int`なので`min_of(3, 2)`がそのまま通ります。

### まとめ

| 観点 | Carbon checked generic | C++ constrained template | C++ unconstrained template |
| --- | --- | --- | --- |
| bodyのcheck | definitionで1回、contractだけを使う | instantiationごと、実際の型で | instantiationごと |
| contract外の操作 | definitionでerror（呼ばれなくても） | 満たす型によっては**通る**。通らない型でinstantiation時にerror | 同左 |
| contractを満たさない呼び出し | call siteでerror、bodyは見ない | call siteでerror（constraints not satisfied） | body内でerror |
| contractの完全さ | copy/destroyまで明示が必要 | 不完全でもcompileできる | contractなし |

## Specialization

```text
$ ./scripts/run-carbon-comparisons.sh   # generic_specialization
1
2
2
```

`impl forall [T: Core.Copy] T as Describe`（blanket impl）と`impl i32 as Describe`が重なり、overlap ruleにより`i32`ではより具体的なimplが選ばれます（generic `CodeOf`の中でも`2`）。pinned nightlyで動作します。C++は`Describe<std::int32_t>`のexplicit specializationで同じ結果です（`min_test`の`test_explicit_specialization`）。

違い: Carbonのspecializationは「どのimplを使うか」の選択で、generic bodyはinterfaceに対してだけcheck済みです。C++のspecializationはclass全体を別物にでき、template bodyはspecializationごとに改めてcheckされます。また、class外で宣言したCarbon implは型のmemberを増やさないので、generic外では`(5 as i32).Code()`が`member name \`Code\` not found in \`i32\``になり、`(5 as i32).(Describe.Code)()`と書きます。

## Compile time / binary size

`scripts/measure-generic-instantiations.sh`は、1 / 4 / 16個の1-field classに`Ordered`を実装し、それぞれで`Min`を1回呼ぶ同じprogramを両言語で生成します。object fileについて次を測ります。

- Min bodies: object内に定義された`Min`関数の数（Carbonは`nm`で`_CMin.`、C++は`nm -C`で` min_of<`）
- .text bytes: `size -A`の`.text*` section合計
- compile s: 3回compileした最短wall-clock（共有machineのため参考値）

```text
Carbon Language toolchain version: 0.0.0-0.nightly.2026.07.11+8be274c
g++ (GCC) 16.2.1 20260810
```

| N | Toolchain | Min bodies | .text bytes | compile s |
| ---: | --- | ---: | ---: | ---: |
| 1 | Carbon --optimize=none | 1 | 191 | 0.30 |
| 1 | Carbon --optimize=speed | 0 | 22 | 0.30 |
| 1 | g++ -O0 | 1 | 175 | 0.06 |
| 1 | g++ -O2 | 0 | 3 | 0.06 |
| 4 | Carbon --optimize=none | 4 | 677 | 0.27 |
| 4 | Carbon --optimize=speed | 0 | 73 | 0.32 |
| 4 | g++ -O0 | 4 | 535 | 0.07 |
| 4 | g++ -O2 | 0 | 3 | 0.06 |
| 16 | Carbon --optimize=none | 16 | 2603 | 0.29 |
| 16 | Carbon --optimize=speed | 0 | 277 | 0.33 |
| 16 | g++ -O0 | 16 | 1975 | 0.09 |
| 16 | g++ -O2 | 0 | 3 | 0.07 |

読み方:

- **pinned nightlyのCarbonはchecked genericを型ごとにspecialize（monomorphize）します。** 最適化なしでは`Min` bodyが型の数だけでき、C++ `-O0`のtemplate instantiationと同じくNに比例して増えます。`min_generic.carbon`のLLVM IRでも、`i32`用と`Version`用の2つが`linkonce_odr`で出ます。

  ```llvm
  define linkonce_odr i32 @_CMin.Main.7deeeb3f4ae1707e(i32 %left, i32 %right)
  define linkonce_odr void @_CMin.Main.7c3ee80e4e9090c9(ptr sret({ i32, i32 }) %return, ptr %left, ptr %right)
  ```

- 最適化すると両言語とも`Min`はinline化されbodyは残りません。g++ `-O2`は結果（すべて0）を定数に畳み、`xor eax, eax; ret`の3 bytesです。Carbon `--optimize=speed`は定数に畳まず、Nに比例したcodeが残ります。
- designは「static dispatchとdynamic dispatchの両方をsupportする」ことをgoalにしています（generics overview）。checked genericはbodyが型に依存しないので、将来はdynamic dispatch（1つのbody + witness table）でbinary sizeを抑える選択肢があります。pinned nightlyで確認できたのはstatic（monomorphization）だけです。
- compile time: この規模ではCarbonは約0.3秒でほぼ一定、g++は0.06〜0.09秒でした。Carbonの時間はprelude処理などの固定費が大半で、「definitionを1回だけcheckする」利点はこの小さなprogramでは測れません。g++の0.06→0.09秒の増加には、instantiationごとのcheckとcodegenが含まれます（測定noiseと同程度の差です）。

## Tradeoffs

| | Carbon checked generics | C++ templates + concepts |
| --- | --- | --- |
| error位置 | definition errorは作者に、call errorは利用者に分かれる | contract漏れは利用者のinstantiationで初めて出る |
| 表現力 | contractにない操作は書けない。copy/destroy/literalの型まで明示が必要 | bodyで何でも使える。duck typingとSFINAE/`if constexpr`で型ごとに挙動を変えられる |
| specialization | impl選択（overlap rule）。bodyのcheckは不変 | 任意のspecialization。bodyはinstantiationごとにcheck |
| binary size | nightlyは型ごとにmonomorphize。designはdynamic dispatchも許す | instantiationごとにcode。`-O0`でNに比例 |
| compile time | definitionのcheckは1回（design上の利点）。nightlyでは固定費が支配的 | instantiationごとにcheckとcodegen |
