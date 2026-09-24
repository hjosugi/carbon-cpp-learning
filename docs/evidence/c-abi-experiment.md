# C ABI experiment evidence

検証日: 2026-09-24

| Item | Value |
| --- | --- |
| Carbon | `0.0.0-0.nightly.2026.07.11+8be274c`（`.carbon-version` / `.carbon-sha256`で固定） |
| C++ compiler | `g++ (GCC) 16.2.1 20260810`（`CXX=clang++`、clang 22.1.8でも同じ結果） |
| Platform | Linux x86_64 |
| Carbon source | [`c_abi_call.carbon`](../../product/loglens/carbon_experiments/c_abi_call.carbon) |
| C ABI | [`c_api.h`](../../product/loglens/include/loglens/c_api.h) / [`c_api.cpp`](../../product/loglens/src/c_api.cpp) |

## Reproduce

```bash
./scripts/bootstrap-carbon.sh
./scripts/run-c-abi-experiment.sh
```

scriptは次の4点をassertし、1つでも外れるとexit 1で止まります。

1. shared libraryが`loglens_bucket_upper`をtext symbol（`T`）としてexportする。
2. Carbonが下げたLLVM IRの宣言が、unmangled Cの`i64 (i32)`である。
3. Carbon executableが`loglens_bucket_upper`をdynamic symbol（`U`）としてimportする。
4. bucket 0/1/31/32の出力がC++ `LatencyHistogram::bucket_upper`の期待値と一致する。

## Build commands

scriptが実行するcommandです（`build_dir=build/c-abi-experiment`）。

```bash
# C++ side: bucket_upper is constexpr in aggregator.hpp, so c_api.cpp is the whole seam.
g++ -std=c++23 -Iproduct/loglens/include -O2 -DNDEBUG \
  -shared -fPIC product/loglens/src/c_api.cpp \
  -o build/c-abi-experiment/libloglens_c_api.so

# Carbon side: the header search path goes to Clang, which parses the imported C++ header.
carbon compile --output-last-input-only \
  --clang-arg=-Iproduct/loglens/include \
  --output=build/c-abi-experiment/c_abi_call.o \
  product/loglens/carbon_experiments/c_abi_call.carbon

# Link: extra Clang link arguments follow `--`.
carbon link --output=build/c-abi-experiment/c_abi_call \
  build/c-abi-experiment/c_abi_call.o -- \
  -Lbuild/c-abi-experiment -lloglens_c_api '-Wl,-rpath,$ORIGIN'
```

pinned nightlyでの注意点:

- `carbon compile`にinclude pathを渡すflagは`--clang-arg=-I...`です。Carbon独自のinclude flagはありません。
- `carbon link --help`には「binary library（archive/shared library）のlinkはTODO」とあります。そのためshared libraryはpositional object fileではなく、`--`以降のClang link argument（`-L`/`-l`/`-rpath`）で渡しています。
- `Core.Print`は`i32`しか受け付けません。C ABIの`uint64_t`は`u64`としてimportされるので、`Core.Print(Cpp.loglens_bucket_upper(0))`は`cannot implicitly convert expression of type 'u64' to 'i32'`になります。experimentでは`Core.PrintChar`で10進数字を1文字ずつ出力します。

## Symbol table (`nm`)

```text
$ nm -D --defined-only build/c-abi-experiment/libloglens_c_api.so | grep -w loglens_bucket_upper
00000000000010f0 T loglens_bucket_upper

$ nm -D --undefined-only build/c-abi-experiment/c_abi_call | grep -w loglens_bucket_upper
                 U loglens_bucket_upper
```

`T`はlibraryのtext sectionにあるglobal definition、`U`はexecutableが実行時に解決するundefined symbolです。C++側は`extern "C"`なのでname manglingがなく、Carbon側の自前functionは`_CPrintBucket.Main`のようにCarbon manglingされます。

```text
$ readelf -d build/c-abi-experiment/c_abi_call | grep -E 'NEEDED|RUNPATH'
 0x000000000000001d (RUNPATH)            Library runpath: [$ORIGIN]
 0x0000000000000001 (NEEDED)             Shared library: [libloglens_c_api.so]
 0x0000000000000001 (NEEDED)             Shared library: [libm.so.6]
 0x0000000000000001 (NEEDED)             Shared library: [libc.so.6]
```

## Calling convention

Carbonが`import Cpp`で受け取った宣言は、Clangと同じC calling conventionへ下がります。

```llvm
; carbon compile --phase=lower --dump-llvm-ir
%loglens_bucket_upper.call = call i64 @loglens_bucket_upper(i32 %bucket)

; Function Attrs: nounwind
declare i64 @loglens_bucket_upper(i32 noundef) #1
```

- `uint32_t` → `u32` → LLVM `i32`、`uint64_t` → `u64` → LLVM `i64`。
- C++の`noexcept`は宣言の`nounwind`として伝わります。
- symbol名は`@loglens_bucket_upper`のままで、adapterやthunkは生成されません。

System V AMD64 ABIでの実際のregister使用（`objdump -dr -M intel`）:

```text
<_CPrintBucket.Main>:                     ; Carbon caller (c_abi_call.o)
  mov    edi,ebx                          ; 1st integer argument: bucket in edi
  call   ... R_X86_64_PLT32 loglens_bucket_upper-0x4
  mov    rdi,rax                          ; 64-bit return value in rax

<loglens_bucket_upper>:                   ; C++ callee (libloglens_c_api.so)
  mov    eax,edi
  test   rax,rax
  je     <loglens_bucket_upper+0x22>
  mov    edx,0x1
  mov    ecx,edi
  shl    rdx,cl
  sub    rdx,0x1
  cmp    rax,0x20
  mov    eax,0xffffffff
  cmovb  rax,rdx
  ret
```

callerは第1引数を`edi`へ置き、callee（GCC build）は`edi`を読み`rax`へ返します。別compilerでbuildした2つのbinaryが、C ABIだけを契約として正しく結合できています。

## Execution output

```text
$ ./scripts/run-c-abi-experiment.sh
Carbon Language toolchain version: 0.0.0-0.nightly.2026.07.11+8be274c
==> Build the C++ shared library
00000000000010f0 T loglens_bucket_upper
==> Compile Carbon against loglens/c_api.h
==> Lowered C call signature
declare i64 @loglens_bucket_upper(i32 noundef) #1
==> Link the Carbon executable against the shared library
                 U loglens_bucket_upper
==> Run and compare the boundary buckets
0 0
1 1
31 2147483647
32 4294967295
C ABI experiment passed.
```

## Boundary values

| Bucket | C++ expected (`bucket_upper`) | Carbon output | Why it is a boundary |
| ---: | ---: | ---: | --- |
| 0 | 0 | 0 | `bucket == 0`の特別扱い |
| 1 | 1 | 1 | 最小の`2^n - 1` |
| 31 | 2147483647 | 2147483647 | 最大の`2^n - 1`（`2^31 - 1`） |
| 32 | 4294967295 | 4294967295 | `bucket >= 32`で`UINT32_MAX`へsaturate |

C++側は`make test`の`test_all_histogram_boundaries`が全33 bucketで`LatencyHistogram::bucket_upper`と`loglens_bucket_upper`の一致を確認します。Carbon側はこのexperimentが同じC ABI経由で4 boundaryを確認します。

## Scope

- Carbonはpre-0.1のため、このexperimentはpinned nightlyだけを対象にし、製品のbuild/runtime dependencyにはしません（[readiness review](../11-readiness-review.md)）。
- CIはCarbon toolchainをinstallしません。`.carbon-version`を更新するときは、`./scripts/run-carbon-smoke.sh`と一緒にこのscriptも再実行してください。
