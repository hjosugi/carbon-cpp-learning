# Class / value semantics evidence

検証日: 2026-09-25

| Item | Value |
| --- | --- |
| Carbon | `0.0.0-0.nightly.2026.07.11+8be274c`（`.carbon-version` / `.carbon-sha256`で固定） |
| C++ compiler | `g++ (GCC) 16.2.1 20260810`、`clang version 22.1.8`（CIはUbuntu 24.04のGCC/Clangで`make test diagnostics`） |
| Platform | Linux x86_64 |
| Carbon sources | [`hands-on/carbon/comparisons/counter_*.carbon`](../../hands-on/carbon/comparisons/) |
| C++ sources | [`hands-on/cpp/counter/`](../../hands-on/cpp/counter/)、[`hands-on/cpp/expect-error/`](../../hands-on/cpp/expect-error/) |
| Design references | [`values.md`](https://docs.carbon-lang.dev/docs/design/values.html)、[`classes.md`](https://docs.carbon-lang.dev/docs/design/classes.html)（2026-09-25確認） |

Issue 005の`Counter` value typeを両言語で書き、field order、initialization、copy、move、destroy、ownershipを比較します。

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-comparisons.sh
make -C hands-on/cpp CXX=g++ test diagnostics
make -C hands-on/cpp CXX=clang++ test diagnostics
```

- `run-carbon-comparisons.sh`: `NAME.carbon`をcompile/link/runし`NAME.expected`と比較します。`expect-error/NAME.carbon`はcheck phaseでrejectされ、`NAME.expected-error`の全行がdiagnosticに含まれることを確認します。
- `make -C hands-on/cpp test`: `-std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror`で`counter_test`をbuild/runします。
- `make -C hands-on/cpp diagnostics`: `expect-error/*.cpp`がcompile errorになり、compiler family（gcc/clang）ごとの短いmessageを出すことを確認します。

## Files

| Topic | Carbon | C++23 |
| --- | --- | --- |
| value type、copy、borrow、consume | [`counter_value.carbon`](../../hands-on/carbon/comparisons/counter_value.carbon) | [`counter.hpp`](../../hands-on/cpp/counter/counter.hpp)、[`counter_test.cpp`](../../hands-on/cpp/counter/counter_test.cpp) |
| `let`と後からのmutation | [`counter_let_alias.carbon`](../../hands-on/carbon/comparisons/counter_let_alias.carbon)（erroneous programの観察） | `test_const_reference_observes_mutation` |
| destructor | [`counter_destroy.carbon`](../../hands-on/carbon/comparisons/counter_destroy.carbon)（design-only部分の観察） | `test_destructor_runs_at_scope_exit` |
| copyできない型 | [`expect-error/counter_no_copy.carbon`](../../hands-on/carbon/comparisons/expect-error/counter_no_copy.carbon) | [`expect-error/counter_log_copy.cpp`](../../hands-on/cpp/expect-error/counter_log_copy.cpp) |
| field initialization | [`expect-error/counter_missing_field.carbon`](../../hands-on/carbon/comparisons/expect-error/counter_missing_field.carbon) | [`expect-error/designated_order.cpp`](../../hands-on/cpp/expect-error/designated_order.cpp) |
| `let`へのmutation | [`expect-error/counter_let_mutate.carbon`](../../hands-on/carbon/comparisons/expect-error/counter_let_mutate.carbon) | `const Counter`への非`const` member call |
| move operator `~x` | [`expect-error/counter_move_operator.carbon`](../../hands-on/carbon/comparisons/expect-error/counter_move_operator.carbon)（design-only） | `std::move` |

## Execution output

```text
$ ./scripts/run-carbon-comparisons.sh
==> counter_destroy
7
1
==> counter_let_alias
2
==> counter_value
1
2
1
3
42
4
3
==> expect-error/counter_let_mutate
counter_let_mutate.carbon:14:3: error: value expression passed to reference parameter
==> expect-error/counter_missing_field
counter_missing_field.carbon:10:10: error: missing value for field `step` in struct initialization
==> expect-error/counter_move_operator
counter_move_operator.carbon:10:24: error: expected expression
==> expect-error/counter_no_copy
counter_no_copy.carbon:10:23: error: cannot copy value of type `Counter`
counter_no_copy.carbon:10:23: note: type `Counter` does not implement interface `Core.Copy`
Carbon comparison labs passed.

$ make -C hands-on/cpp CXX=g++ test diagnostics
==> build/g++/counter/counter_test
counter_test: 9 tests passed
g++ (GCC) 16.2.1 20260810
==> expect-error/counter_log_copy.cpp (gcc)
error: use of deleted function
==> expect-error/designated_order.cpp (gcc)
error: designator order for field
C++ diagnostic checks passed.

$ make -C hands-on/cpp CXX=clang++ test diagnostics
==> build/clang++/counter/counter_test
counter_test: 9 tests passed
clang version 22.1.8
==> expect-error/counter_log_copy.cpp (clang)
error: call to deleted constructor of
==> expect-error/designated_order.cpp (clang)
ISO C++ requires field designators to be specified in declaration order
C++ diagnostic checks passed.
```

`counter_value`の7行は、名前順を入れ替えた初期化（1）、copy後のoriginal（2）とcopy（1）、pointer経由の`Bump`（3）、temporaryを消費する`Finish`（42）、named variableをcopyして消費する`Finish`（4）、消費後も変わらないoriginal（3）です。C++の`counter_test`は同じ順序で同じ値を`CHECK`します。

## Compiler diagnostics

Carbon（全文）:

```text
$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/counter_let_mutate.carbon
hands-on/carbon/comparisons/expect-error/counter_let_mutate.carbon:14:3: error: value expression passed to reference parameter
  counter.Increment();
  ^~~~~~~
hands-on/carbon/comparisons/expect-error/counter_let_mutate.carbon:7:16: note: initializing function parameter
  fn Increment(ref self) {
               ^~~~~~~~

$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/counter_missing_field.carbon
hands-on/carbon/comparisons/expect-error/counter_missing_field.carbon:10:10: error: missing value for field `step` in struct initialization
  return {.value = 1};
         ^~~~~~~~~~~~

$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/counter_move_operator.carbon
hands-on/carbon/comparisons/expect-error/counter_move_operator.carbon:10:24: error: expected expression
  var moved: Counter = ~counter;
                       ^

hands-on/carbon/comparisons/expect-error/counter_move_operator.carbon:10:24: error: `var` declarations must end with a `;`
  var moved: Counter = ~counter;
                       ^

hands-on/carbon/comparisons/expect-error/counter_move_operator.carbon:10:24: error: semantics TODO: `handle invalid parse trees in `check``
  var moved: Counter = ~counter;
                       ^

$ carbon compile --phase=check hands-on/carbon/comparisons/expect-error/counter_no_copy.carbon
hands-on/carbon/comparisons/expect-error/counter_no_copy.carbon:10:23: error: cannot copy value of type `Counter`
  var copy: Counter = counter;
                      ^~~~~~~
hands-on/carbon/comparisons/expect-error/counter_no_copy.carbon:10:23: note: type `Counter` does not implement interface `Core.Copy`
  var copy: Counter = counter;
                      ^~~~~~~
```

C++（GCC 16.2.1）:

```text
expect-error/counter_log_copy.cpp:9:36: error: use of deleted function ‘compare::CounterLog::CounterLog(const compare::CounterLog&)’
    9 |   const compare::CounterLog copy = log;
      |                                    ^~~
./counter/counter.hpp:58:3: note: declared here
   58 |   CounterLog(const CounterLog&) = delete;
      |   ^~~~~~~~~~
expect-error/designated_order.cpp:8:54: error: missing initializer for member ‘compare::CounterState::value’ [-Werror=missing-field-initializers]
expect-error/designated_order.cpp:8:54: error: designator order for field ‘compare::CounterState::value’ does not match declaration order in ‘compare::CounterState’
```

C++（Clang 22.1.8）:

```text
expect-error/counter_log_copy.cpp:9:29: error: call to deleted constructor of 'const compare::CounterLog'
./counter/counter.hpp:58:3: note: 'CounterLog' has been explicitly marked deleted here
expect-error/designated_order.cpp:8:53: error: ISO C++ requires field designators to be specified in declaration order; field 'step' will be initialized after field 'value' [-Werror,-Wreorder-init-list]
```

Clangではdesignator順序違反はwarning（`-Wreorder-init-list`）で、labの`-Werror`がerrorにしています。GCCは常にerrorです。

## Comparison table

| Topic | Carbon（pinned nightly） | C++23 |
| --- | --- | --- |
| field order / layout | declaration order。`var value: i32; var step: i32;` | declaration order。`sizeof(Counter) == 8`、`offsetof(CounterState, step) == 4`を`static_assert` |
| initialization | constructorはなく、factory `Create`がstruct literalを返す。fieldは**名前で**対応し順序は自由（`{.step = 10, .value = 1}`が通る）。fieldを省くとerror | constructor / aggregate。designated initializerは**宣言順**が必須。省いたfieldは0で初期化され、`-Wextra`のwarningだけ |
| receiver | `fn Get(self)`は値、`fn Increment(ref self)`は変更 | `get() const`と非`const` member |
| immutable binding | `let`はvalue。`ref self` methodを呼ぶと`value expression passed to reference parameter` | `const` objectへの非`const` member callはerror |
| copy | **opt-in**。`impl Counter as Core.Copy`がないと`cannot copy value of type`。copyは独立object | **opt-out**。rule of zeroで自動生成、禁止は`= delete` |
| move | `~x`はprovisional design（docs/design/README.md "Move"）でnightlyはparseしない。所有権はtemporaryを`var` parameterへ直接初期化して渡す | `std::move`はnon-destructive。trivially copyableな`Counter`ではcopyと同じで、移動元も値を保つ |
| consuming parameter | `fn Finish(var counter: Counter)`。temporaryはcopyなし、named variableは`Core.Copy`でcopy | `finish(Counter counter)`。prvalueはcopy elision、lvalueはcopy |
| non-owning access | `Counter*`（`&counter`、`counter->Increment()`）。allocation/解放なし | `Counter&` |
| heap ownership | pinned nightlyのCoreにallocation APIはない（`lib/carbon/core`にheap/newなし） | `std::unique_ptr<Counter>`、`std::vector`。owning raw pointerなし |
| destructor | `fn destroy(ref self)`はcompileされるが、scope exitで呼ばれない（`counter_destroy`は`7`、`1`だけを出す） | destructorは必ずscope exitで実行（`ScopeProbe`で確認） |

## Ownership and lifetime

- **所有者は変数**: 両言語とも`var counter`（C++では`auto counter`）がstorageを所有し、scopeの終わりでlifetimeが終わります。`Bump(&counter)`と`bump(counter)`は借用だけで、所有権もallocationも移りません。owning raw pointerはどちらの版にもありません。
- **copyの既定値が逆**: C++の`Counter`は何も書かなくてもcopy可能です。Carbonのclassは`Core.Copy`をimplするまでcopyできず、`CounterLog`のような「copyしてはいけない型」はCarbonでは既定の状態です。
- **`let`はsnapshotではない**: Carbonの`let view: Counter = counter;`はcopyせず、objectの値を束縛します（`Core.Copy`をimplしていても同じ）。design（values.md "Value expressions"）は、束縛後にobjectをmutationするとvalue bindingのlifetimeが終わり、その後の使用はerror（undefined behaviorではなく"erroneous"）と定めています。pinned nightlyはこれを検出せず、`counter_let_alias`は変更後の`2`を出します。C++の`const Counter&`も同じく変更を観測しますが、C++ではwell-definedです。snapshotが欲しい場合は両言語とも`var`（C++では値）でcopyします。
- **consumeとmove**: Carbonは消費を`var` parameterで宣言し、temporaryならcopyなしで渡ります。C++のby-value parameterとcopy elisionに近いですが、C++の`std::move`が移動元を「valid but unspecified」に残すのに対し、Carbonの`~x`（provisional）は移動元をunformed stateにするdestructive moveを目指しています。
- **destructor**: C++のRAIIはdestructorが必ず走ることに依存します。pinned nightlyのCarbonはuser `destroy`を実行しないので、Carbon側でresource解放をdestructorに任せるコードはまだ書けません。

## Design-only parts

次は設計に存在するがpinned nightlyでは動かない部分です。上記checkが挙動を固定しているので、nightly更新で変わるとscriptが失敗して気づけます。

| Feature | Design | Pinned nightly |
| --- | --- | --- |
| move operator `~x` | provisional（docs/design/README.md "Move"） | `error: expected expression` |
| user destructor `fn destroy(ref self)` | classes.md "Destructors" | compileされるがscope exitで呼ばれない |
| mutation後の`let`使用の検出 | values.md "Value expressions"（erroneous） | 検出せず、変更後の値を読む |
| heap allocation | 設計途中 | Coreにallocation APIなし |
