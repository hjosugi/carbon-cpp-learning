# Carbon toolchain pipeline trace

検証日: 2026-09-24

```text
$ carbon version
Carbon Language toolchain version: 0.0.0-0.nightly.2026.07.11+8be274c
```

`fn Add(a: i32, b: i32) -> i32 { return a + b; }`の`a + b`を、tokenからobject fileまで追跡します。出力はすべてpinned nightlyで実行した結果です。

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-pipeline-trace.sh
```

scriptは各phaseのdumpを`build/pipeline-trace/`へ保存し、次をassertします。1つでも外れるとexit 1です。

- `+`が各phaseに残っている: `Plus` token、`InfixOperatorPlus` node、SemIRの`Int.as.AddWith.impl.Op.call`、LLVM IRの`add i32 %a, %b`、objectの`_CAdd.PipelineTrace`。
- 3つのerror fileが、直前のphaseでは成功し、担当phaseで期待するdiagnosticを出して失敗する。

| File | Purpose |
| --- | --- |
| [`add.carbon`](../../hands-on/carbon/pipeline-trace/add.carbon) | 追跡する関数 |
| [`lex-error.carbon`](../../hands-on/carbon/pipeline-trace/lex-error.carbon) | lex phaseのdiagnostic |
| [`syntax-error.carbon`](../../hands-on/carbon/pipeline-trace/syntax-error.carbon) | parse phaseのdiagnostic |
| [`type-error.carbon`](../../hands-on/carbon/pipeline-trace/type-error.carbon) | check phaseのdiagnostic |

## Phase input/output

`carbon compile --phase=<phase>`は指定phaseまでを順に実行して止まります（`carbon compile --help`: "These phases are always run in sequence, so every phase before the one selected will also be run. The default is to compile to machine code."）。

| Phase | Input | Output | Dump | Diagnostics it owns (examples) |
| --- | --- | --- | --- | --- |
| Source | file path | source buffer | - | `error opening file for read` |
| Lex | source buffer | token buffer（kind、位置、indent、括弧の対応、identifier ID） | `--dump-tokens` | invalid numeric literal、不正な文字 |
| Parse | token buffer | postorderのparse tree（`subtree_size`付き） | `--dump-parse-tree` | 欠けた`;`など文法error |
| Check | parse tree + imported Core prelude | SemIR（型、name解決、interface impl） | `--dump-sem-ir` / `--dump-raw-sem-ir` | 型変換、name lookup、代入不可 |
| Lower | SemIR | LLVM IR module | `--dump-llvm-ir` | （通常はuser diagnosticなし） |
| Optimize | LLVM IR | 最適化済みLLVM IR | `--phase=optimize --dump-llvm-ir` | - |
| CodeGen | LLVM IR | object file / assembly | `--output=FILE`、`--output=-`、`--asm-output` | - |

## `carbon help`

```text
$ carbon help
...
Usage:
  carbon [OPTIONS] build-runtimes [OPTIONS]
  carbon [OPTIONS] build [OPTIONS] <FILE>... -- [<CLANG-ARG>... -- <EXTRA_CLANG_LINK_ARGS>...]
  carbon [OPTIONS] clang [<ARG>...]
  carbon [OPTIONS] compile [OPTIONS] <FILE>... -- [<CLANG-ARG>...]
  carbon [OPTIONS] config [OPTIONS]
  carbon [OPTIONS] format [--output=FILE] <FILE>...
  carbon [OPTIONS] language-server
  carbon [OPTIONS] link [OPTIONS] [<OBJECT_FILE>... -- <EXTRA_CLANG_LINK_ARGS>...]
  carbon [OPTIONS] lld [OPTIONS] [<ARG>...]
  carbon [OPTIONS] llvm ar [<ARG>...]
  ...（llvm subcommandが続く）

Subcommands:
  build-runtimes   Build Carbon's runtime libraries.
  build            Compile and then link Carbon and C++ source code into a single executable.
  clang            Runs Clang on arguments.
  compile          Compile Carbon source code.
  config           Print configuration info for the Carbon toolchain.
  format           Format Carbon source code.
  language-server  Runs the language server.
  link             Link Carbon executables.
  lld              Runs LLD with the provided arguments.
  llvm             Runs LLVM's command line tools with the provided arguments.
  help             Prints help information for the command, ...
  version          Prints the version of this command.
```

（subcommandの説明は1行に詰めています。全文は`build/pipeline-trace/help.txt`。）

`carbon compile --help`のphase/dump関連option:

```text
--phase[=(lex|parse|check|lower|optimize|codegen)]
--stream-errors
--dump-shared-values
--dump-tokens
--omit-file-boundary-tokens
--dump-parse-tree
--preorder-parse-tree
--dump-raw-sem-ir
--dump-sem-ir
--dump-cpp-ast
--dump-sem-ir-ranges[=(if-present|only|ignore)]
--builtin-sem-ir
--dump-llvm-ir
--dump-asm
--dump-mem-usage
--dump-timings
--exclude-dump-file-prefix=PREFIX
```

pinned nightlyでの注意点:

- `--dump-sem-ir`と`--dump-llvm-ir`は暗黙importされるCore preludeのfileも出力します。`add.carbon`だけでもSemIRは約147,000行、LLVM IRは31 module・約800行になるため、scriptは`--exclude-dump-file-prefix=<toolchain>/lib/carbon/core`で除外しています。
- `--dump-asm`は何も出力しませんでした。assemblyは`--output=-`（stdoutへtextual assembly）で取得しています。

## Trace of `a + b`

### Lex (`--dump-tokens`)

```text
$ carbon compile --phase=lex --dump-tokens add.carbon
- filename: add.carbon
  tokens:
  - { index:  0, kind:       "FileStart", line: 1, column:  1, indent: 1, spelling: "" }
  - { index:  1, kind:         "Package", line: 3, column:  1, indent: 1, spelling: "package", has_leading_space: true }
  - { index:  2, kind:      "Identifier", line: 3, column:  9, indent: 1, spelling: "PipelineTrace", identifier: 0, has_leading_space: true }
  - { index:  3, kind:            "Semi", line: 3, column: 22, indent: 1, spelling: ";" }
  - { index:  4, kind:              "Fn", line: 5, column:  1, indent: 1, spelling: "fn", has_leading_space: true }
  - { index:  5, kind:      "Identifier", line: 5, column:  4, indent: 1, spelling: "Add", identifier: 1, has_leading_space: true }
  - { index:  6, kind:       "OpenParen", line: 5, column:  7, indent: 1, spelling: "(", closing_token: 14 }
  - { index:  7, kind:      "Identifier", line: 5, column:  8, indent: 1, spelling: "a", identifier: 2 }
  - { index:  8, kind:           "Colon", line: 5, column:  9, indent: 1, spelling: ":" }
  - { index:  9, kind:  "IntTypeLiteral", line: 5, column: 11, indent: 1, spelling: "i32", has_leading_space: true }
  - { index: 10, kind:           "Comma", line: 5, column: 14, indent: 1, spelling: "," }
  - { index: 11, kind:      "Identifier", line: 5, column: 16, indent: 1, spelling: "b", identifier: 3, has_leading_space: true }
  - { index: 12, kind:           "Colon", line: 5, column: 17, indent: 1, spelling: ":" }
  - { index: 13, kind:  "IntTypeLiteral", line: 5, column: 19, indent: 1, spelling: "i32", has_leading_space: true }
  - { index: 14, kind:      "CloseParen", line: 5, column: 22, indent: 1, spelling: ")", opening_token: 6 }
  - { index: 15, kind:    "MinusGreater", line: 5, column: 24, indent: 1, spelling: "->", has_leading_space: true }
  - { index: 16, kind:  "IntTypeLiteral", line: 5, column: 27, indent: 1, spelling: "i32", has_leading_space: true }
  - { index: 17, kind:  "OpenCurlyBrace", line: 5, column: 31, indent: 1, spelling: "{", closing_token: 23, has_leading_space: true }
  - { index: 18, kind:          "Return", line: 6, column:  3, indent: 3, spelling: "return", has_leading_space: true }
  - { index: 19, kind:      "Identifier", line: 6, column: 10, indent: 3, spelling: "a", identifier: 2, has_leading_space: true }
  - { index: 20, kind:            "Plus", line: 6, column: 12, indent: 3, spelling: "+", has_leading_space: true }
  - { index: 21, kind:      "Identifier", line: 6, column: 14, indent: 3, spelling: "b", identifier: 3, has_leading_space: true }
  - { index: 22, kind:            "Semi", line: 6, column: 15, indent: 3, spelling: ";" }
  - { index: 23, kind: "CloseCurlyBrace", line: 7, column:  1, indent: 1, spelling: "}", opening_token: 17, has_leading_space: true }
  - { index: 24, kind:         "FileEnd", line: 7, column:  2, indent: 1, spelling: "", has_leading_space: true }
```

- `a + b`はtoken 19〜21の`Identifier` / `Plus` / `Identifier`です。
- `i32`はidentifierではなく`IntTypeLiteral` tokenです。sized type literalはlexerが認識します。
- 同じ名前は同じ`identifier` IDを共有します（parameterの`a`とbodyの`a`はどちらも`2`）。
- 括弧の対応（`closing_token` / `opening_token`）はlex時点で確定しています。commentはtokenになりません。

### Parse (`--dump-parse-tree`)

```text
$ carbon compile --phase=parse --dump-parse-tree add.carbon
- filename: add.carbon
  parse_tree: [
    {kind: 'FileStart', text: ''},
      {kind: 'PackageIntroducer', text: 'package'},
      {kind: 'IdentifierPackageName', text: 'PipelineTrace'},
    {kind: 'PackageDecl', text: ';', subtree_size: 3},
        {kind: 'FunctionIntroducer', text: 'fn'},
        {kind: 'IdentifierNameMaybeBeforeSignature', text: 'Add'},
          {kind: 'ExplicitParamListStart', text: '('},
            {kind: 'IdentifierNameNotBeforeSignature', text: 'a'},
            {kind: 'IntTypeLiteral', text: 'i32'},
          {kind: 'LetBindingPattern', text: ':', subtree_size: 3},
          {kind: 'PatternListComma', text: ','},
            {kind: 'IdentifierNameNotBeforeSignature', text: 'b'},
            {kind: 'IntTypeLiteral', text: 'i32'},
          {kind: 'LetBindingPattern', text: ':', subtree_size: 3},
        {kind: 'ExplicitParamList', text: ')', subtree_size: 9},
          {kind: 'IntTypeLiteral', text: 'i32'},
        {kind: 'ReturnType', text: '->', subtree_size: 2},
      {kind: 'FunctionDefinitionStart', text: '{', subtree_size: 14},
        {kind: 'ReturnStatementStart', text: 'return'},
          {kind: 'IdentifierNameExpr', text: 'a'},
          {kind: 'IdentifierNameExpr', text: 'b'},
        {kind: 'InfixOperatorPlus', text: '+', subtree_size: 3},
      {kind: 'ReturnStatement', text: ';', subtree_size: 5},
    {kind: 'FunctionDefinition', text: '}', subtree_size: 20},
    {kind: 'FileEnd', text: ''},
  ]
```

- treeはpostorderで、親nodeは子の後に来ます。`subtree_size`は自分を含むsubtreeのnode数で、`InfixOperatorPlus`の3は`a`、`b`、自分です（`--preorder-parse-tree`でpreorder表示）。
- 同じ`a`でも位置によってnode kindが違います。parameterは`IdentifierNameNotBeforeSignature`、式の中では`IdentifierNameExpr`です。
- この段階では型も名前解決もありません。`i32`は`IntTypeLiteral` nodeのままです。

### Check (`--dump-sem-ir`)

```text
$ carbon compile --phase=check --dump-sem-ir \
    --exclude-dump-file-prefix=<toolchain>/lib/carbon/core add.carbon
--- add.carbon

constants {
  %int_32: Core.IntLiteral = int_value 32 [concrete]
  %Int.type: type = generic_class_type @Int [concrete]
  ...
  %i32: type = class_type @Int, @Int(%int_32) [concrete]
  ...
  %Add.type: type = fn_type @Add [concrete]
  %Add: %Add.type = struct_value () [concrete]
  %AddWith.type.2ef: type = generic_interface_type @AddWith [concrete]
  ...
  %AddWith.impl_witness.0c8: <witness> = impl_witness imports.%AddWith.impl_witness_table.f16, @Int.as.AddWith.impl.f51(%int_32) [concrete]
  ...
}

imports {
  ...
  %Core.Int: %Int.type = import_ref Core//prelude/types/int, Int, loaded [concrete = constants.%Int.generic]
  %Core.AddWith: %AddWith.type.2ef = import_ref Core//prelude/operators/arithmetic, AddWith, loaded [concrete = constants.%AddWith.generic]
  ...
}

fn @Add(%a.param: %i32, %b.param: %i32) -> out %return.param: %i32 {
!entry:
  %a.ref: %i32 = name_ref a, %a
  %b.ref: %i32 = name_ref b, %b
  %impl.elem1: %.f1b = impl_witness_access constants.%AddWith.impl_witness.0c8, element1 [concrete = constants.%Int.as.AddWith.impl.Op.3f3]
  %bound_method.loc6_12.1: <bound method> = bound_method %a.ref, %impl.elem1
  %specific_fn: <specific function> = specific_function %impl.elem1, @Int.as.AddWith.impl.Op.1(constants.%int_32) [concrete = constants.%Int.as.AddWith.impl.Op.specific_fn.353]
  %bound_method.loc6_12.2: <bound method> = bound_method %a.ref, %specific_fn
  %Int.as.AddWith.impl.Op.call: init %i32 = call %bound_method.loc6_12.2(%a.ref, %b.ref)
  return %Int.as.AddWith.impl.Op.call

!observes:
}
```

（`...`は省略。全87行は`build/pipeline-trace/sem-ir.txt`。）

- `i32`はCore preludeの`Int(N)` classを`N = 32`で具体化した`class_type @Int, @Int(%int_32)`になります。
- `+`はoperator専用の命令ではなく、`Core.AddWith` interfaceの呼び出しです。`i32`向けimplのwitnessから`Op`を取り出し（`impl_witness_access`）、`N = 32`に具体化し（`specific_function`）、`a`をreceiverとして呼びます。
- 呼ばれる`Op`はpreludeの`Int(N) as AddWith(Self)` implで、`fn Op(self, other: Self) -> Self = "int.sadd";`というbuiltinです（`lib/carbon/core/prelude/types/int.carbon`、import_refの`loc141`/`loc142`）。
- 型が合わない式はこのphaseでerrorになります（後述のtype error）。

### Lower (`--dump-llvm-ir`)

```text
$ carbon compile --phase=lower --dump-llvm-ir \
    --exclude-dump-file-prefix=<toolchain>/lib/carbon/core add.carbon
; ---
; ModuleID = 'add.carbon'
source_filename = "add.carbon"

; Function Attrs: nounwind
define i32 @_CAdd.PipelineTrace(i32 %a, i32 %b) #0 !dbg !4 {
entry:
  %Int.as.AddWith.impl.Op.call = add i32 %a, %b, !dbg !11
  ret i32 %Int.as.AddWith.impl.Op.call, !dbg !12
}

attributes #0 = { nounwind }
...
```

- `Add`は`_CAdd.PipelineTrace`（`_C` + 名前 + `.` + package）へmangleされます。
- builtin `int.sadd`の呼び出しはfunction callではなく、1つの`add i32`命令としてloweringされます。LLVM valueの名前には`Int.as.AddWith.impl.Op.call`が残ります。
- これはまだ最適化前です。`--phase=optimize --dump-llvm-ir`ではLLVM passが`memory(none)`、`willreturn`などのattributeと`local_unnamed_addr`を付け、`add i32 %b, %a`へ並べ替えます。

### CodeGen (`--output=-`, object file)

```text
$ carbon compile --output-last-input-only --output=- add.carbon
	.globl	_CAdd.PipelineTrace
	.type	_CAdd.PipelineTrace,@function
_CAdd.PipelineTrace:
	leal	(%rdi,%rsi), %eax
	retq
...

$ carbon compile --output-last-input-only --output=build/pipeline-trace/add.o add.carbon
$ nm build/pipeline-trace/add.o
0000000000000000 T _CAdd.PipelineTrace
```

（`.loc`、`.cfi_*`、debug section等のdirectiveは省略。）

x86-64 instruction selectionは`add i32`を`lea`へ変えます。System V ABIどおり`a`は`edi`、`b`は`esi`、戻り値は`eax`です。objectにはmangle済みの`_CAdd.PipelineTrace`がglobal text symbol（`T`）として残ります。

## Diagnostic owner phase

diagnosticは既定でsource位置順に並べ替えて表示されます（`--stream-errors`で発生順）。さらに後段phaseも不正な入力に対して動き続けるため、出力の順番や内容だけではどのphaseが検出したか判別できません。そこで`--phase`を1段ずつ進め、最初に失敗するphaseをowner phaseとします。scriptはこの手順を自動で確認します。

| File | `--phase=lex` | `--phase=parse` | `--phase=check` | Owner |
| --- | --- | --- | --- | --- |
| `lex-error.carbon` | **error** | error | error | Lex |
| `syntax-error.carbon` | ok | **error** | error | Parse |
| `type-error.carbon` | ok | ok | **error** | Check |

### Lex error

```text
$ carbon compile --phase=lex lex-error.carbon
lex-error.carbon:6:13: error: invalid digit 'G' in hexadecimal numeric literal
  return 0x1G;
            ^
```

### Syntax error (parse)

```text
$ carbon compile --phase=lex syntax-error.carbon     # exit 0
$ carbon compile --phase=parse syntax-error.carbon
syntax-error.carbon:6:1: error: `return` statements must end with a `;`
}
^
```

parserは`return x + 1`の後に`;`を期待し、次のtoken（6行目の`}`）の位置で報告します。`--phase=check`まで進めると、同じfileに対してcheck phaseが`semantics TODO`のdiagnostic（handle invalid parse trees in check）も追加で出します。check phaseは不正なparse treeを受け取っても動きますが、原因を検出したのはparse phaseです。

### Type error (check)

```text
$ carbon compile --phase=parse type-error.carbon     # exit 0
$ carbon compile --phase=check type-error.carbon
type-error.carbon:7:3: error: cannot implicitly convert expression of type `f64` to `i32`
  return x;
  ^~~~~~~~~
type-error.carbon:7:3: note: type `f64` does not implement interface `Core.ImplicitAs(i32)`
  return x;
  ^~~~~~~~~
```

parse treeとしては正しいので`--phase=parse`は成功します。return値の`f64`を`i32`へ変換できるか（`Core.ImplicitAs(i32)`のimplがあるか）はcheck phaseが初めて判断します。

## Annotated pipeline

```text
add.carbon ─────────────────────────────── Source: file read
  │                                         diag: error opening file for read
  ▼
Lex ──────────── --dump-tokens            25 tokens: Identifier(a) Plus Identifier(b) ...
  │                                         i32 = IntTypeLiteral, brackets paired
  │                                         diag: invalid digit 'G' in hexadecimal numeric literal
  ▼
Parse ────────── --dump-parse-tree        postorder: IdentifierNameExpr(a) IdentifierNameExpr(b)
  │                                         InfixOperatorPlus (subtree_size: 3)
  │                                         diag: `return` statements must end with a `;`
  ▼
Check ────────── --dump-sem-ir            i32 = Core.Int(32); `+` = Core.AddWith impl call
  │  (+ Core prelude import)                (builtin "int.sadd")
  │                                         diag: cannot implicitly convert `f64` to `i32`
  ▼
Lower ────────── --dump-llvm-ir           define i32 @_CAdd.PipelineTrace(i32 %a, i32 %b)
  │                                         add i32 %a, %b
  ▼
Optimize ─────── --phase=optimize          LLVM passes: attributes, canonical operand order
  │              --dump-llvm-ir
  ▼
CodeGen ──────── --output=- / --output=FILE
  │                                         leal (%rdi,%rsi), %eax ; retq
  ▼
add.o ─────────── nm                        T _CAdd.PipelineTrace
```

## Scope

- 出力はpinned nightly `0.0.0-0.nightly.2026.07.11`のものです。Carbonはpre-0.1なので、token kind、parse node名、SemIRの表記、manglingはnightly更新で変わりえます。`.carbon-version`を更新したら`./scripts/run-carbon-pipeline-trace.sh`を再実行してください。
- CIの`Carbon labs (pinned nightly)` jobがpinned nightlyをinstallし、`./scripts/check-carbon.sh`経由でこのscriptも毎回実行します。
- phase構成の公式説明: [Toolchain architecture](https://docs.carbon-lang.dev/toolchain/docs/)、[nightly release](https://github.com/carbon-language/carbon-lang/releases/tag/v0.0.0-0.nightly.2026.07.11)（2026-09-24確認）。
