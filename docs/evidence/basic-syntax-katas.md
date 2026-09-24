# Basic syntax katas evidence

検証日: 2026-09-24

Carbon: `0.0.0-0.nightly.2026.07.11+8be274c`（`.carbon-version` / `.carbon-sha256`で固定）

Issue 004の4つのkataの解答例です。`nightly-smoke/`は学習者が自分で変更する出発点なので変更せず、解答例は[`hands-on/carbon/solutions/`](../../hands-on/carbon/solutions/)に置いています。

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-katas.sh
```

scriptは次を確認し、1つでも外れるとexit 1で止まります。

- `solutions/NAME.carbon`をcompile、link、実行し、stdoutが`NAME.expected`と完全一致する。
- `solutions/expect-error/NAME.carbon`がcheck phaseでrejectされ、`NAME.expected-error`のdiagnosticを出す。

## Kata sources

| Kata | Starting point | Solution | Boundary inputs |
| --- | --- | --- | --- |
| `Clamp` | `nightly-smoke/01_functions.carbon` | [`clamp.carbon`](../../hands-on/carbon/solutions/clamp.carbon) | below low, `low`, inside, `high`, above high |
| tuple loop count | `nightly-smoke/03_tuple.carbon` | [`tuple_loop_count.carbon`](../../hands-on/carbon/solutions/tuple_loop_count.carbon) | 1, 2, 13, 21 |
| named struct result | `nightly-smoke/03_tuple.carbon` | [`struct_result.carbon`](../../hands-on/carbon/solutions/struct_result.carbon) | 1, 2, 13, 21 |
| lossy `as` | - | [`as_conversion.carbon`](../../hands-on/carbon/solutions/as_conversion.carbon) | 100, 32767, 32768, 40000 |

`SmallestFactor`は元のsmoke labのままだと`SmallestFactor(1)`がloopを1回も回らず`(1, true)`、つまり「1は素数」を返します。解答例では`value <= 1`を「素数ではなく、iteration 0」とするcontractにしました（`docs/02-carbon-hands-on.md` Lab 2の課題）。

## Execution output

```text
$ ./scripts/run-carbon-katas.sh
==> as_conversion
100
32767
-32768
-25536
==> clamp
0
0
5
10
10
==> struct_result
1
0
0
2
1
0
13
1
11
3
0
2
==> tuple_loop_count
1
0
0
2
1
0
13
1
11
3
0
2
==> expect-error/implicit_narrowing
hands-on/carbon/solutions/expect-error/implicit_narrowing.carbon:7:21: error: cannot implicitly convert expression of type `i32` to `i16`
==> expect-error/let_reassign
hands-on/carbon/solutions/expect-error/let_reassign.carbon:6:3: error: expression is not assignable
Carbon katas passed.
```

`SmallestFactor`の出力は1入力につき`factor`、`is_prime`（`Core.Print`は`i32`だけを受け付けるので1/0）、`iterations`の3行です。

| Input | factor | is_prime | iterations | Note |
| ---: | ---: | ---: | ---: | --- |
| 1 | 1 | 0 | 0 | `value <= 1` contract |
| 2 | 2 | 1 | 0 | `candidate < value`が最初からfalse |
| 13 | 13 | 1 | 11 | candidate 2..12をすべて試す |
| 21 | 3 | 0 | 2 | candidate 2、3で停止 |

tuple版とstruct版は同じ出力です。違いはcall siteで、`result.1`は位置の意味を覚えている必要がありますが、`result.is_prime`は名前で読めます。

## Compiler diagnostics

```text
$ carbon compile --phase=check hands-on/carbon/solutions/expect-error/let_reassign.carbon
hands-on/carbon/solutions/expect-error/let_reassign.carbon:6:3: error: expression is not assignable
  answer = 43;
  ^~~~~~

$ carbon compile --phase=check hands-on/carbon/solutions/expect-error/implicit_narrowing.carbon
hands-on/carbon/solutions/expect-error/implicit_narrowing.carbon:7:21: error: cannot implicitly convert expression of type `i32` to `i16`
  let narrow: i16 = wide;
                    ^~~~
hands-on/carbon/solutions/expect-error/implicit_narrowing.carbon:7:21: note: type `i32` does not implement interface `Core.ImplicitAs(i16)`
  let narrow: i16 = wide;
                    ^~~~
```

## `let` / `var` / tuple / struct / `as`

| Concept | Carbon | C++23 comparison |
| --- | --- | --- |
| `let` | 再代入できないbinding。代入すると`expression is not assignable`。 | `const` local |
| `var` | 変更できるobject。`++iterations`や`=`で更新する。 | non-`const` local |
| tuple | 位置で読む無名aggregate。`(i32, bool, i32)`、`.0`/`.1`/`.2`。 | `std::tuple`、structured binding |
| struct result | 名前で読むaggregate。`{.factor: i32, ...}`、`.factor`。 | named `struct` |
| implicit conversion | 値を失わない変換だけ。`i32`→`i16`は`Core.ImplicitAs(i16)`がないのでerror。 | narrowingも暗黙に通る（brace initializationを除く） |
| `as` | 明示的な変換。`i32`→`i16`は下位16 bitを残し、`32768`は`-32768`、`40000`は`-25536`になる。 | `static_cast<std::int16_t>` |

lossy conversionに`as`が必要なのは、値が変わりうる変換をsourceに明示させるためです。C++では`std::int16_t n = wide;`がそのままcompileされます（`-Wconversion`でwarningになる程度）が、Carbonはcheck phaseでrejectします。
