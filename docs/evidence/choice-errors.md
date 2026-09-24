# Choice / errors-as-values evidence

検証日: 2026-09-25

| Item | Value |
| --- | --- |
| Carbon | `0.0.0-0.nightly.2026.07.11+8be274c`（`.carbon-version` / `.carbon-sha256`で固定） |
| C++ compiler | `g++ (GCC) 16.2.1 20260810`、`clang version 22.1.8`（CIはUbuntu 24.04のGCC/Clangで`make test diagnostics`） |
| Platform | Linux x86_64 |
| Carbon sources | [`parse_result.carbon`](../../hands-on/carbon/comparisons/parse_result.carbon)（`.input` / `.expected`）、[`expect-error/parse_result_choice.carbon`](../../hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon)、[`expect-error/choice_equality.carbon`](../../hands-on/carbon/comparisons/expect-error/choice_equality.carbon) |
| C++ sources | [`errors/parse_result.hpp`](../../hands-on/cpp/errors/parse_result.hpp)、[`errors/parse_result_test.cpp`](../../hands-on/cpp/errors/parse_result_test.cpp)、[`expect-error/variant_missing_alternative.cpp`](../../hands-on/cpp/expect-error/variant_missing_alternative.cpp)、[`expect-error/switch_missing_enumerator.cpp`](../../hands-on/cpp/expect-error/switch_missing_enumerator.cpp) |
| Design references | [Sum types](https://docs.carbon-lang.dev/docs/design/sum_types.html)、[Pattern matching](https://docs.carbon-lang.dev/docs/design/pattern_matching.html)（2026-09-25確認） |

Issue 007のparser resultを、Carbonの`choice` / errors-as-valuesとC++の`std::expected`・`std::variant`・exceptionで比べます。題材はLogLensのlatency fieldと同じ「1行を10進数のlatencyとしてparseする」関数です。

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-comparisons.sh
make -C hands-on/cpp CXX=g++ test diagnostics
make -C hands-on/cpp CXX=clang++ test diagnostics
```

`run-carbon-comparisons.sh`は`NAME.input`があればstdinへ渡します。`parse_result`は`parse_result.input`の9行を読み、行ごとに結果を出します。

## Error contract

invalid inputはparserにとって通常のeventです。どの行も必ず値を1つ返し、error後も次の行を処理します。

| Input line | Result | Carbon output | Why |
| --- | --- | ---: | --- |
| `17` | Ok(17) | 17 | |
| （空行） | Empty | -1 | 文字がない |
| `1x` | NotDigit | -2 | `x`は0-9でない |
| `2147483647` | Ok(2147483647) | 2147483647 | `i32` max |
| `2147483648` | Overflow | -3 | `i32` maxを超える |
| `0` | Ok(0) | 0 | |
| `-5` | NotDigit | -2 | 符号は受け付けない |
| ` 7` | NotDigit | -2 | 前後の空白は受け付けない |
| `99999999999999999999` | Overflow | -3 | 桁ごとに上限を確認するので`i64`もoverflowしない |

- 最初のerrorを返します（`12x4`はNotDigit、position 2）。
- Carbon版は1行を最後まで読み切ってから結果を返すので、次の行の読み取り位置がずれません。
- C++の`parse_result_test`は同じ9行を`std::expected`版と`std::variant`版の両方で確認し、Carbonと同じ数値になることを`CHECK`します。

## Execution output

```text
$ ./scripts/run-carbon-comparisons.sh
...
==> parse_result
17
-1
-2
2147483647
-3
0
-2
-2
-3
...
==> expect-error/choice_equality
choice_equality.carbon:12:10: error: cannot access member of interface `Core.EqWith(ParseErrorCode)` in type `ParseErrorCode` that does not implement that interface
==> expect-error/parse_result_choice
parse_result_choice.carbon:8:5: error: semantics TODO: `choice alternatives with parameters are not yet supported`
parse_result_choice.carbon:15:3: error: semantics TODO: `HandleMatchIntroducer`
parse_result_choice.carbon:16:19: error: expected `,` or `)`
Carbon comparison labs passed.

$ make -C hands-on/cpp CXX=g++ test
...
==> build/g++/errors/parse_result_test
parse_result_test: 5 tests passed
```

C++ testはCIのClang 18 + libstdc++ 13でも動きます。この組み合わせは`std::expected`を提供しないため、LogLens本体と同じ`loglens/result.hpp`のfallback adapterを使います。localでは`-DLOGLENS_FORCE_RESULT_FALLBACK`付きbuildでもpassすることを確認しました。

## Carbon: design and pinned nightly

designの形は[`expect-error/parse_result_choice.carbon`](../../hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon)です。

```carbon
choice ParseResult {
  Ok(value: i32),
  Empty,
  NotDigit(position: i32),
  Overflow
}

fn Code(result: ParseResult) -> i32 {
  match (result) {
    case .Ok(value: i32) => { return 0; }
    case .Empty => { return 1; }
    case .NotDigit(position: i32) => { return 2; }
    case .Overflow => { return 3; }
  }
}
```

pinned nightlyの全diagnostic:

```text
$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon
hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon:8:5: error: semantics TODO: `choice alternatives with parameters are not yet supported`
  Ok(value: i32),
    ^~~~~~~~~~~~

hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon:10:11: error: semantics TODO: `choice alternatives with parameters are not yet supported`
  NotDigit(position: i32),
          ^~~~~~~~~~~~~~~

hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon:15:3: error: semantics TODO: `HandleMatchIntroducer`
  match (result) {
  ^~~~~

hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon:16:19: error: expected `,` or `)`
    case .Ok(value: i32) => { return 0; }
                  ^

hands-on/carbon/comparisons/expect-error/parse_result_choice.carbon:18:28: error: expected `,` or `)`
    case .NotDigit(position: i32) => { return 2; }
                           ^

$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/choice_equality.carbon
hands-on/carbon/comparisons/expect-error/choice_equality.carbon:12:10: error: cannot access member of interface `Core.EqWith(ParseErrorCode)` in type `ParseErrorCode` that does not implement that interface
  return code == ParseErrorCode.Empty;
         ^~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

- payload付きalternativeと`match`は未実装です（`semantics TODO`）。`case .Ok(value: i32)`はdesign（pattern_matching.md）の書き方ですが、nightlyのparserはalternative pattern内のbindingを受け付けません（`expected \`,\` or \`)\``）。
- payloadなしの`choice ParseErrorCode { Empty, NotDigit, Overflow }`は宣言も値の生成もできますが、`==`も`match`もないので分岐できません。
- そのため実行版の[`parse_result.carbon`](../../hands-on/carbon/comparisons/parse_result.carbon)は、tag（`code: i32`）とpayload（`value: i32`）を持つclassでsum typeを表します。compilerはtagとpayloadの対応を保証しないので、`ParseResult.Ok` / `ParseResult.Error`のfactory以外で作らないという約束で守っています。
- 実行版で見つかった他のnightlyの制限:
  - `Core.EOF()`を呼ぶとcompileは通りますがlinkで`ld.lld: error: undefined symbol: _CEOF.Core`になります（`str.Size()`も同様に`_CSize.String.Core`）。`Core.ReadChar()`の-1を直接比較しています。
  - `ref` parameterへの引数はcall siteでも`ParseLine(ref at_end)`と書く必要があります（書かないと`argument to \`ref\` parameter not marked with \`ref\``）。

## C++: `std::expected` / `std::variant` / exception

| | `std::expected<std::int32_t, ParseErrorCode>` | `std::variant<Ok, Empty, NotDigit, Overflow>` | exception |
| --- | --- | --- | --- |
| error payload | error型は1つ（enum） | alternativeごとに別のpayload（`NotDigit::position`） | exception object |
| call siteの分岐 | `if (result)` / `result.error()` | `std::visit` + `Overloaded` | `try` / `catch`（書かなくてもcompileできる） |
| alternative追加時 | enumeratorを足す。`switch`は`-Wswitch`でwarning、`-Werror`でerror | visitorが全alternativeを扱わないとcompile error | 呼び出し側は何も変わらず、catchされないexceptionがruntimeに出る |
| Carbonで近い形 | `choice`のpayloadを1種類にした形 | `choice ParseResult`そのもの | なし（Carbonはerrors-are-values） |

alternative追加の影響をcompile errorで確認します（`make diagnostics`）。

```text
$ g++ ... -fsyntax-only expect-error/variant_missing_alternative.cpp
/usr/include/c++/16/variant:1145:14: error: no type named ‘type’ in ‘struct std::invoke_result<compare::Overloaded<...>, const compare::Overflow&>’

$ clang++ ... -fsyntax-only expect-error/variant_missing_alternative.cpp
.../include/c++/16/type_traits:3413:5: error: no type named 'type' in 'std::invoke_result<compare::Overloaded<...>, const compare::Overflow &>'

$ g++ ... -fsyntax-only expect-error/switch_missing_enumerator.cpp
expect-error/switch_missing_enumerator.cpp:10:10: error: enumeration value ‘overflow’ not handled in switch [-Werror=switch]

$ clang++ ... -fsyntax-only expect-error/switch_missing_enumerator.cpp
expect-error/switch_missing_enumerator.cpp:10:11: error: enumeration value 'overflow' not handled in switch [-Werror,-Wswitch]
```

`std::visit`のerrorはstandard library内部を指し、message文言もlibstdc++のversionで変わります。checkは、compileが失敗することと、漏れたalternative名`compare::Overflow`が出ることだけを確認します。

## Adding an alternative

新しいfailure（たとえば`NegativeNotAllowed`）を足した時の影響:

| Style | 変更が必要な場所 | 見落とした時 |
| --- | --- | --- |
| Carbon `choice` + `match`（design） | `default`のない`match`すべて | designでは網羅していない`match`はcompile error（pattern_matching.md "Refutability, overlap, usefulness, and exhaustiveness"）。`default`を書いた`match`は黙って`default`へ流れる |
| Carbon tagged class（nightly実行版） | codeを読む`if`すべて | compilerは何も言わない。testだけが頼り |
| C++ `std::variant` + `std::visit` | visitorすべて | compile error（`variant_missing_alternative.cpp`） |
| C++ `std::expected` + enum `switch` | `switch`すべて | `-Wall`のwarning、`-Werror`でerror。`default:`があると検出されない |
| C++ exception | throwする側だけ | 誰もcatchしなければruntimeでterminate |

exhaustiveな分岐は、alternative追加をAPIのbreaking changeとして全call siteへ知らせます。LogLensのparse error codeのように呼び出し側が全caseを処理すべき閉じた集合ではこれが利点です。外部利用者がいるAPIで後からalternativeを足す予定なら、`default`（C++では`default:`や汎用lambda）で受ける部分を残すか、versionを上げます。

## Why not exceptions, and when to use them

LogLensのparserは`std::expected`（`loglens::Result`）を返し、exceptionを使いません。

- invalid lineは入力の一部であり、異常ではありません。adversarial inputで大半の行がinvalidでも、1行ごとの`throw`/`catch`のcostと、hidden control flowを持ち込みません（`test_invalid_input_is_a_normal_event`）。
- errorが型に出るので、呼び出し側は必ずerrorの存在を知り、`[[nodiscard]]`で無視も検出できます。exception版の`parse_latency_or_throw`は、`try`を書かなくてもcompileが通ります（`test_exception_version_hides_the_error_path`）。
- parser、C ABI（`loglens_bucket_upper`は`noexcept`）、Carbonとのinterop境界をexceptionが越えません。Carbonはerrors-are-valuesを原則にしており、C++ exceptionを受ける仕組みを前提にできません。

exceptionが適する場合:

- 呼び出し側がその場で回復できず、上位へ一気に戻すしかない失敗。例: `std::bad_alloc`、constructorの失敗、programのinvariant違反。
- 深いcall stackの途中にerror処理を書きたくない、稀な失敗。
- 標準libraryやthird-party APIがexceptionで報告するもの。LogLensの`main`は`std::bad_alloc`だけを境界でcatchし、stderrへmessageを出してexit code 5へ変換します（stdoutのmachine-readable出力は壊しません）。

判断の軸は「そのfailureは通常の入力として頻繁に起きるか」と「直接の呼び出し側が処理できるか」です。どちらかがyesならvalue、両方noならexceptionを検討します。
