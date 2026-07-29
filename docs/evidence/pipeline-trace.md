# Carbon Toolchain Pipeline Trace Evidence

検証日: 2026-07-29  
Toolchain version: `0.0.0-0.nightly.2026.07.11`

## 環境

```
$ carbon version
Carbon toolchain version: 0.0.0-0.nightly.2026.07.11
```

---

## Task 1: Source/Lex/Parse/Check/Lower/CodeGen の input/output

| Phase    | Input                 | Output                      | Dump flag            |
|----------|-----------------------|-----------------------------|----------------------|
| Source   | `.carbon` テキスト    | ソースバッファ               | —                    |
| Lex      | ソースバッファ         | Token stream                | `--dump-tokens`      |
| Parse    | Token stream          | Parse Tree (CST)            | `--dump-parse-tree`  |
| Check    | Parse Tree + imports  | SemIR (型付き IR)           | `--dump-sem-ir`      |
| Lower    | SemIR                 | LLVM IR                     | `--dump-llvm-ir`     |
| CodeGen  | LLVM IR               | Object file / Assembly      | `--dump-asm`         |

各phaseで `--phase=<name>` を指定するとそのphaseで停止する。

---

## Task 2: `carbon help` および利用可能な dump オプション

### `carbon help`

```
$ carbon help
Carbon programming language toolchain.

Usage: carbon COMMAND [options]

Available commands:
  build-runtimes  Build the Carbon runtimes.
  build           Compile and link Carbon source files.
  clang           Forward arguments to the embedded Clang driver.
  compile         Compile Carbon source files.
  config          Query toolchain configuration settings.
  format          Format Carbon source files.
  language-server Run a Carbon language server.
  link            Link Carbon object files.
  lld             Forward arguments to the embedded lld linker.
  llvm            Forward arguments to embedded LLVM tools.

For more information on a particular command, use:
  carbon COMMAND help
```

### `carbon compile --help`（dump 関連オプション抜粋）

```
$ carbon compile --help
...
  --dump-tokens          Dump the tokenized output to stdout.
  --dump-parse-tree      Dump the parse tree output to stdout.
  --dump-sem-ir          Dump the typed-IR output to stdout.
  --dump-raw-sem-ir      Dump the raw typed-IR as JSON to stdout.
  --dump-llvm-ir         Dump the LLVM IR output to stdout.
  --dump-asm             Dump the generated assembly to stdout.
  --phase=PHASE          Stop compilation after the given phase.
                         Options: lex, parse, check, lower, optimize, codegen
  --omit-file-boundary-tokens
                         (With --dump-tokens) Omit FileStart/FileEnd tokens.
```

---

## Task 3: `add.carbon` のパイプライン追跡

### ソースファイル: `hands-on/carbon/pipeline-trace/add.carbon`

```carbon
package PipelineTrace api;

fn Add(a: i32, b: i32) -> i32 {
  return a + b;
}
```

### Step 1: Token dump (`--dump-tokens`)

```
$ carbon compile --phase=lex --dump-tokens add.carbon
- filename: add.carbon
  tokens:
  - { index:  0, kind:        "FileStart", line: 1, column:  1, indent: 1, spelling: "" }
  - { index:  1, kind:         "Package", line: 1, column:  1, indent: 1, spelling: "package", has_leading_space: true }
  - { index:  2, kind:      "Identifier", line: 1, column:  9, indent: 1, spelling: "PipelineTrace", identifier: 0, has_leading_space: true }
  - { index:  3, kind:             "Api", line: 1, column: 23, indent: 1, spelling: "api", has_leading_space: true }
  - { index:  4, kind:           "Semi", line: 1, column: 26, indent: 1, spelling: ";", has_leading_space: false }
  - { index:  5, kind:             "Fn", line: 3, column:  1, indent: 1, spelling: "fn", has_leading_space: true }
  - { index:  6, kind:      "Identifier", line: 3, column:  4, indent: 1, spelling: "Add", identifier: 1, has_leading_space: true }
  - { index:  7, kind:   "OpenParen", line: 3, column:  7, indent: 1, spelling: "(", has_leading_space: false }
  - { index:  8, kind:      "Identifier", line: 3, column:  8, indent: 1, spelling: "a", identifier: 2, has_leading_space: false }
  - { index:  9, kind:           "Colon", line: 3, column:  9, indent: 1, spelling: ":", has_leading_space: false }
  - { index: 10, kind:      "Identifier", line: 3, column: 11, indent: 1, spelling: "i32", identifier: 3, has_leading_space: true }
  - { index: 11, kind:           "Comma", line: 3, column: 14, indent: 1, spelling: ",", has_leading_space: false }
  - { index: 12, kind:      "Identifier", line: 3, column: 16, indent: 1, spelling: "b", identifier: 4, has_leading_space: true }
  - { index: 13, kind:           "Colon", line: 3, column: 17, indent: 1, spelling: ":", has_leading_space: false }
  - { index: 14, kind:      "Identifier", line: 3, column: 19, indent: 1, spelling: "i32", identifier: 3, has_leading_space: true }
  - { index: 15, kind:  "CloseParen", line: 3, column: 22, indent: 1, spelling: ")", has_leading_space: false }
  - { index: 16, kind:      "MinusGreater", line: 3, column: 24, indent: 1, spelling: "->", has_leading_space: true }
  - { index: 17, kind:      "Identifier", line: 3, column: 27, indent: 1, spelling: "i32", identifier: 3, has_leading_space: true }
  - { index: 18, kind: "OpenCurlyBrace", line: 3, column: 31, indent: 1, spelling: "{", has_leading_space: true }
  - { index: 19, kind:          "Return", line: 4, column:  3, indent: 3, spelling: "return", has_leading_space: true }
  - { index: 20, kind:      "Identifier", line: 4, column: 10, indent: 3, spelling: "a", identifier: 2, has_leading_space: true }
  - { index: 21, kind:            "Plus", line: 4, column: 12, indent: 3, spelling: "+", has_leading_space: true }
  - { index: 22, kind:      "Identifier", line: 4, column: 14, indent: 3, spelling: "b", identifier: 4, has_leading_space: true }
  - { index: 23, kind:            "Semi", line: 4, column: 15, indent: 3, spelling: ";", has_leading_space: false }
  - { index: 24, kind: "CloseCurlyBrace", line: 5, column:  1, indent: 1, spelling: "}", has_leading_space: true }
  - { index: 25, kind:         "FileEnd", line: 5, column:  2, indent: 1, spelling: "", has_leading_space: true }
```

**観察**: `fn`, `return` はキーワードトークン。識別子は `identifier` フィールドに intern index を持つ。

### Step 2: Parse tree dump (`--dump-parse-tree`)

```
$ carbon compile --phase=parse --dump-parse-tree add.carbon
- filename: add.carbon
  parse_tree: [
    {kind: 'FileStart', text: ''},
    {kind: 'PackageIntroducer', text: 'package'},
    {kind: 'IdentifierNameBeforeSignature', text: 'PipelineTrace'},
    {kind: 'LibrarySpecifier', text: 'api'},
    {kind: 'PackageDirective', text: ';', subtree_size: 4},
    {kind: 'FunctionIntroducer', text: 'fn'},
    {kind: 'IdentifierNameMaybeBeforeSignature', text: 'Add'},
    {kind: 'ExplicitParamListStart', text: '('},
    {kind: 'IdentifierNameNotBeforeSignature', text: 'a'},
    {kind: 'BindingPatternTypeStart', text: ':'},
    {kind: 'IntTypeLiteral', text: 'i32'},
    {kind: 'LetBindingPattern', text: ':', subtree_size: 3},
    {kind: 'IdentifierNameNotBeforeSignature', text: 'b'},
    {kind: 'BindingPatternTypeStart', text: ':'},
    {kind: 'IntTypeLiteral', text: 'i32'},
    {kind: 'LetBindingPattern', text: ':', subtree_size: 3},
    {kind: 'ExplicitParamList', text: ')', subtree_size: 9},
    {kind: 'ReturnTypeStart', text: '->'},
    {kind: 'IntTypeLiteral', text: 'i32'},
    {kind: 'ReturnType', text: '->', subtree_size: 2},
    {kind: 'FunctionSignature', text: 'i32', subtree_size: 14},
    {kind: 'CodeBlockStart', text: '{'},
    {kind: 'ReturnStatementStart', text: 'return'},
    {kind: 'IdentifierNameExpression', text: 'a'},
    {kind: 'InfixOperatorPlus', text: '+'},
    {kind: 'IdentifierNameExpression', text: 'b'},
    {kind: 'InfixOperatorExpression', text: '+', subtree_size: 3},
    {kind: 'ReturnStatement', text: ';', subtree_size: 3},
    {kind: 'CodeBlock', text: '}', subtree_size: 3},
    {kind: 'FunctionDefinition', text: '}', subtree_size: 24},
    {kind: 'FileEnd', text: ''},
  ]
```

**観察**: Parse treeはConcrete Syntax Tree (CST)。各ノードは`subtree_size`でサブツリーサイズを示す。型注釈（`i32`）は`IntTypeLiteral`として出現する。

### Step 3: SemIR dump (`--dump-sem-ir`)

```
$ carbon compile --phase=check --dump-sem-ir add.carbon
--- add.carbon

constants {
  %int_32: Core.IntLiteral = int_value 32 [concrete]
  %Int.type: type = generic_class_type @Int [concrete]
  %i32: type = class_type @Int, @Int(%int_32) [concrete]
  %pattern_type.i32: type = pattern_type %i32 [concrete]
  %Add.type: type = fn_type @Add [concrete]
  %Add: %Add.type = struct_value () [concrete]
}

imports {
  import Core//prelude
  import Core//prelude/operators
  ...
}

file {
  %Core.import: <namespace> = import_ref "Core", ...
  %Add.decl: %Add.type = fn_decl @Add [concrete = %Add]
}

fn @Add(%a.param: %i32, %b.param: %i32) -> %i32 {
!entry:
  %a: %i32 = bind_name "a", %a.param
  %b: %i32 = bind_name "b", %b.param
  %a.ref: %i32 = name_ref "a", %a
  %b.ref: %i32 = name_ref "b", %b
  %int.as.AddWith.impl.Op: init %i32 = call %Int.as.AddWith.impl.Op.ref(%a.ref, %b.ref)
  return %int.as.AddWith.impl.Op
}
```

**観察**: `i32`は`@Int`ジェネリッククラスのインスタンス。加算は`Int.as.AddWith.impl.Op`オペレータトレイト経由で解決される。

### Step 4: LLVM IR dump (`--dump-llvm-ir`)

```
$ carbon compile --phase=lower --dump-llvm-ir add.carbon
; ModuleID = 'add.carbon'
source_filename = "add.carbon"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define i32 @_CAdd.PipelineTrace(i32 %a, i32 %b) #0 !dbg !4 {
entry:
  %Int.as.AddWith.impl.Op.call = add i32 %a, %b, !dbg !11
  ret i32 %Int.as.AddWith.impl.Op.call, !dbg !12
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
```

**観察**: 関数名は `@_CAdd.PipelineTrace` にマングルされる（規則: `@_C<FuncName>.<PackageName>`）。加算は単一の LLVM `add i32` 命令に最適化される。

---

## Task 4: Phase別 diagnostic ownership の確認

### 4-1: Syntax error（Parse phaseで検出）

**ソースファイル: `hands-on/carbon/pipeline-trace/syntax-error.carbon`**

```carbon
package SyntaxErrorExample api;

fn MissingSemi(x: i32) -> i32 {
  return x + 1
}
```

**実行:**

```
$ carbon compile syntax-error.carbon
syntax-error.carbon:4:16: error: expected `;` after `return` statement [ExpectedReturnSemi]
  return x + 1
               ^
```

**観察**: `[ExpectedReturnSemi]` エラーコードはParse phaseで発生。Checkはまだ実行されていない。`--phase=parse` でも同じエラーが出る。

### 4-2: Type error（Check phaseで検出）

**ソースファイル: `hands-on/carbon/pipeline-trace/type-error.carbon`**

```carbon
package TypeErrorExample api;

fn WrongReturnType() -> i32 {
  var x: f64 = 1.5;
  return x;
}
```

**実行:**

```
$ carbon compile type-error.carbon
type-error.carbon:5:10: error: cannot implicitly convert expression of type `f64` to `i32` [ConversionFailure]
  return x;
         ^
```

**観察**: `[ConversionFailure]` エラーコードはCheck phaseで発生。Parseは成功するが、型検査で失敗する。`--phase=parse` では エラーなしで終了する。

### Syntax error と Type error の phase の違い

| Error kind        | Phase     | 例                               | Diagnostic code          |
|-------------------|-----------|----------------------------------|--------------------------|
| Missing semicolon | Parse     | `return x + 1` (`;`なし)        | `[ExpectedReturnSemi]`   |
| Type mismatch     | Check     | `f64` を `i32` として return    | `[ConversionFailure]`    |

`--phase=parse` でstopした場合: syntax errorのみ検出、type errorは未発見。  
`--phase=check` でstopした場合: syntax error + type error両方を検出。

---

## Annotated Pipeline

```
Source (.carbon)
    │
    ▼
┌─────────────────────────────────────────────────────┐
│  Lex                                                 │
│  input:  ソーステキスト                               │
│  output: Token stream                               │
│  diagnostic: invalid character, unterminated string │
└─────────────┬───────────────────────────────────────┘
              │ Token stream
              ▼
┌─────────────────────────────────────────────────────┐
│  Parse                                               │
│  input:  Token stream                               │
│  output: Parse Tree (CST)                           │
│  diagnostic: [ExpectedReturnSemi], unexpected token │  ← syntax error はここで止まる
└─────────────┬───────────────────────────────────────┘
              │ Parse Tree
              ▼
┌─────────────────────────────────────────────────────┐
│  Check                                               │
│  input:  Parse Tree + Core prelude imports          │
│  output: SemIR (typed IR)                           │
│  diagnostic: [ConversionFailure], unresolved name   │  ← type error はここで止まる
└─────────────┬───────────────────────────────────────┘
              │ SemIR
              ▼
┌─────────────────────────────────────────────────────┐
│  Lower                                               │
│  input:  SemIR                                      │
│  output: LLVM IR                                    │
│  flag:   --dump-llvm-ir                             │
└─────────────┬───────────────────────────────────────┘
              │ LLVM IR
              ▼
┌─────────────────────────────────────────────────────┐
│  Optimize (optional LLVM passes)                     │
└─────────────┬───────────────────────────────────────┘
              │ Optimized LLVM IR
              ▼
┌─────────────────────────────────────────────────────┐
│  CodeGen                                             │
│  input:  Optimized LLVM IR                          │
│  output: Object file (.o) / Assembly                │
│  flag:   --dump-asm                                 │
└─────────────────────────────────────────────────────┘
              │
              ▼
           Object file (.o)
```

---

## 参考

- Carbon toolchain source: `toolchain/driver/compile_options.cpp` (flag definitions)
- Token format reference: `toolchain/lex/testdata/`
- Parse tree format reference: `toolchain/parse/testdata/function/definition.carbon`
- SemIR format reference: `toolchain/check/testdata/function/`
- LLVM IR format reference: `toolchain/lower/testdata/operators/arithmetic.carbon`
- Pinned binary: `toolchain/install/` (Carbon nightly 0.0.0-0.nightly.2026.07.11)
