# C ABI experiment evidence

Carbon nightly: `0.0.0-0.nightly.2026.07.11`
検証日: 2026-07-29

## Build commands

```sh
# 1. C++ shared library
g++ -std=c++23 \
    -Iproduct/loglens/include \
    -O2 -DNDEBUG \
    -shared -fPIC \
    product/loglens/src/c_api.cpp \
    product/loglens/src/aggregator.cpp \
    -o build/c-abi-experiment/libloglens_c_api.so

# 2. Carbon compile
carbon compile \
    -include-search-root=product/loglens/include \
    --output=build/c-abi-experiment/c_abi_call.o \
    product/loglens/carbon_experiments/c_abi_call.carbon

# 3. Link
carbon link \
    --output=build/c-abi-experiment/c_abi_call \
    build/c-abi-experiment/c_abi_call.o \
    build/c-abi-experiment/libloglens_c_api.so
```

## nm output

### libloglens_c_api.so (exported symbol)

```
$ nm -D build/c-abi-experiment/libloglens_c_api.so | grep loglens
0000000000001149 T loglens_bucket_upper
```

Symbol type `T` — text (code) section, global (exported).

### c_abi_call (undefined / imported from shared library)

```
$ nm -D build/c-abi-experiment/c_abi_call | grep loglens
                 U loglens_bucket_upper
```

Symbol type `U` — undefined; resolved at link time from `libloglens_c_api.so`.

## Calling convention

`loglens_bucket_upper` follows the **System V AMD64 ABI** (C calling convention):

| | Detail |
|---|---|
| Parameter | `uint32_t bucket` — passed in `edi` (lower 32 bits of `rdi`) |
| Return | `uint64_t` — returned in `rax` |
| Exception | `noexcept` — no stack unwinding metadata |

Carbon's C++ interop resolves the `extern "C"` declaration directly; no name-mangling adapter is generated.

## Execution output

```
$ LD_LIBRARY_PATH=build/c-abi-experiment ./build/c-abi-experiment/c_abi_call
0
1
2147483647
4294967295
```

### Boundary value table

| Bucket | C++ `bucket_upper` | Carbon output | Match |
|---:|---:|---:|:---:|
| 0 | 0 | 0 | ✓ |
| 1 | 1 | 1 | ✓ |
| 31 | 2147483647 | 2147483647 | ✓ |
| 32 | 4294967295 | 4294967295 | ✓ |

Buckets 0 and 32 are the saturation boundaries (`bucket == 0 → 0`, `bucket >= 32 → UINT32_MAX`).
Buckets 1 and 31 are the minimum and maximum non-saturated values.
All four match the values verified by `test_all_histogram_boundaries` in `tests/test_main.cpp`.

## Reproduce

```sh
bash scripts/bootstrap-carbon.sh
bash scripts/run-c-abi-experiment.sh
```
