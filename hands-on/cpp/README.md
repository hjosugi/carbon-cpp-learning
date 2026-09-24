# C++23 comparison labs

Carbon版（`hands-on/carbon/comparisons/`）と対になるC++23 codeとtestは、このdirectoryで実行できます。

```bash
make CXX=g++ test diagnostics
make CXX=clang++ test diagnostics
```

- `test`: `*_test.cpp`を`-std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror`でbuildして実行する。
- `diagnostics`: `expect-error/NAME.cpp`がcompile errorになり、`NAME.gcc.expected-error`または`NAME.clang.expected-error`の各行を出すことを確認する。

| Lab | Code | Evidence |
| --- | --- | --- |
| `Counter` value type（Issue 005） | [`counter/`](counter/) | [class/value semantics](../../docs/evidence/class-value-semantics.md) |
| `Min` with concepts（Issue 006） | [`generics/`](generics/) | [checked generics](../../docs/evidence/checked-generics.md) |
| `std::expected` / `std::variant` / exception（Issue 007） | [`errors/`](errors/) | [choice/errors-as-values](../../docs/evidence/choice-errors.md) |

## 1. Result type

`std::expected<Record, ParseError>`をexception版と比較します。invalid inputが通常eventであるparserに、なぜvalue resultが適するか説明してください。

## 2. Zero-copy parse

`product/loglens/src/parser.cpp`の`std::string_view`を`std::string`へ変え、allocation数とlifetime safetyのtradeoffを調べます。

## 3. Exact vs approximate p95

すべてのlatencyを`std::vector`へ保存するexact版を作り、fixed histogram版と比較します。

- correctness error
- update cost
- report cost
- memory at 100M lines

## 4. Concepts vs checked generics

C++ conceptで`Min`を実装します。definition bodyでconceptにないoperationを使った時のdiagnosticをCarbonの目標と比較します。

## 5. API boundary

histogramの`bucket_upper`をC ABIで公開します。exceptionを越境させず、fixed-width integerだけを使ってください。

## 6. Production hardening

次を1つずつ追加します。

- stdin input (`--input -`)
- max unique service guard
- report schema version
- Prometheus text output
- benchmark target
- fuzz target for `parse_line`

対応issueは`issues/`にあります。
