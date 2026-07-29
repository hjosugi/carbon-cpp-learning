# basic syntax katasを実装する

Labels: `area/carbon`, `type/learning`, `priority/p1`

Depends on: #003

## Tasks

- [x] `Clamp`を実装する
- [x] tupleへloop countを追加する
- [x] tuple resultをnamed struct resultへ変更する
- [x] lossy `as` conversionのpositive/negative exampleを作る

## Acceptance criteria

boundary inputを含む実行結果があり、`let`/`var`、tuple/struct、explicit conversionを説明できる。

## Evidence

### Source diff

**`01_functions.carbon`** — `Clamp`を追加、boundary testをprintする。

```diff
+fn Clamp(value: i32, low: i32, high: i32) -> i32 {
+  if (value < low) { return low; }
+  if (value > high) { return high; }
+  return value;
+}
+
 fn Run() {
   let answer: i32 = Double(21);
   Core.Print(answer);
+  // Clamp boundary tests: below low, at low, middle, at high, above high.
+  Core.Print(Clamp(-5, 0, 10));
+  Core.Print(Clamp(0, 0, 10));
+  Core.Print(Clamp(5, 0, 10));
+  Core.Print(Clamp(10, 0, 10));
+  Core.Print(Clamp(15, 0, 10));
 }
```

**`03_tuple.carbon`** — tuple戻り値を3要素にし、loop countを追加する。

```diff
-fn SmallestFactor(value: i32) -> (i32, bool) {
+fn SmallestFactor(value: i32) -> (i32, bool, i32) {
   var candidate: i32 = 2;
+  var iterations: i32 = 0;
   while (candidate < value) {
+    ++iterations;
     if (value % candidate == 0) {
-      return (candidate, false);
+      return (candidate, false, iterations);
     }
     ++candidate;
   }
-  return (value, true);
+  return (value, true, iterations);
 }
 
 fn Run() {
-  let result: (i32, bool) = SmallestFactor(21);
+  let result: (i32, bool, i32) = SmallestFactor(21);
   Core.Print(result.0);
   if (result.1) { Core.Print(1); } else { Core.Print(0); }
+  Core.Print(result.2);
 }
```

**`04_struct.carbon`** (new) — named struct resultで同じAPIを再実装する。

```carbon
import Core library "io";

fn SmallestFactor(value: i32) -> {.factor: i32, .is_prime: bool, .iterations: i32} {
  var candidate: i32 = 2;
  var iterations: i32 = 0;
  while (candidate < value) {
    ++iterations;
    if (value % candidate == 0) {
      return {.factor = candidate, .is_prime = false, .iterations = iterations};
    }
    ++candidate;
  }
  return {.factor = value, .is_prime = true, .iterations = iterations};
}

fn Run() {
  let result: {.factor: i32, .is_prime: bool, .iterations: i32} = SmallestFactor(21);
  Core.Print(result.factor);
  if (result.is_prime) { Core.Print(1); } else { Core.Print(0); }
  Core.Print(result.iterations);
}
```

**`05_conversion.carbon`** (new) — lossy `as` conversionのpositive/negative example。

```carbon
import Core library "io";

fn Run() {
  // Positive example: value fits in i16; no data loss.
  var pos: i32 = 100;
  let pos16: i16 = pos as i16;
  Core.Print(pos16 as i32);  // 100

  // Negative example: value overflows i16; data is lost (wraps modulo 2^16).
  var neg: i32 = 40000;
  let neg16: i16 = neg as i16;
  Core.Print(neg16 as i32);  // -25536  (40000 - 65536)
}
```

### Expected run output

```
$ ./scripts/run-carbon-smoke.sh
==> 00_hello
42
==> 01_functions
42
0
0
5
10
10
==> 02_control_flow
55
==> 03_tuple
3
0
5
==> 04_struct
3
0
5
==> 05_conversion
100
-25536
Carbon smoke labs passed.
```

### `let` / `var` / tuple / struct / conversion の説明

| 概念 | Carbon | C++23 比較 |
| --- | --- | --- |
| `let` | immutable binding。再代入するとcompile error。 | `const` local variable |
| `var` | mutable binding。`++`や`=`で変更可能。 | non-const local variable |
| tuple | 匿名・位置ベースのaggregate。`.0`, `.1`でアクセス。 | `std::tuple` |
| named struct result | 名前付きフィールドのaggregate。`.factor`でアクセス。 | `struct` / `std::pair` with named fields |
| `as` (lossy) | narrowing conversionを明示的に要求。コンパイラがsilentに値を切り捨てない。 | `static_cast` |

