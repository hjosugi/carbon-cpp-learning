#!/usr/bin/env bash
# run-c-abi-experiment.sh
# Builds the C++ shared library, compiles the Carbon interop file, links, runs
# nm to confirm the symbol table, then executes and checks boundary values.
#
# Prerequisites: Carbon toolchain installed via ./scripts/bootstrap-carbon.sh
# Usage: bash scripts/run-c-abi-experiment.sh
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
carbon="${root_dir}/.tools/carbon_toolchain-${version}/bin/carbon"
loglens_dir="${root_dir}/product/loglens"
build_dir="${root_dir}/build/c-abi-experiment"

if [[ ! -x "${carbon}" ]]; then
  echo "Carbon toolchain missing. Run ./scripts/bootstrap-carbon.sh first." >&2
  exit 2
fi

mkdir -p "${build_dir}"
echo "==> Build dir: ${build_dir}"

# ── Step 1: compile C++ shared library ──────────────────────────────────────
echo
echo "==> Step 1: compile libloglens_c_api.so"
g++ -std=c++23 \
    -I"${loglens_dir}/include" \
    -O2 -DNDEBUG \
    -shared -fPIC \
    "${loglens_dir}/src/c_api.cpp" \
    "${loglens_dir}/src/aggregator.cpp" \
    -o "${build_dir}/libloglens_c_api.so"
echo "OK: ${build_dir}/libloglens_c_api.so"

# ── Step 2: verify exported symbol with nm ───────────────────────────────────
echo
echo "==> Step 2: nm -D libloglens_c_api.so | grep loglens"
nm -D "${build_dir}/libloglens_c_api.so" | grep loglens_bucket_upper

# ── Step 3: compile Carbon source ────────────────────────────────────────────
echo
echo "==> Step 3: carbon compile c_abi_call.carbon"
"${carbon}" compile \
    -include-search-root="${loglens_dir}/include" \
    --output="${build_dir}/c_abi_call.o" \
    "${loglens_dir}/carbon_experiments/c_abi_call.carbon"
echo "OK: ${build_dir}/c_abi_call.o"

# ── Step 4: link ─────────────────────────────────────────────────────────────
echo
echo "==> Step 4: carbon link c_abi_call"
"${carbon}" link \
    --output="${build_dir}/c_abi_call" \
    "${build_dir}/c_abi_call.o" \
    "${build_dir}/libloglens_c_api.so"
echo "OK: ${build_dir}/c_abi_call"

# ── Step 5: confirm symbol reference in executable ──────────────────────────
echo
echo "==> Step 5: nm -D c_abi_call | grep loglens"
nm -D "${build_dir}/c_abi_call" | grep loglens_bucket_upper

# ── Step 6: run and check boundary values ────────────────────────────────────
echo
echo "==> Step 6: execute and verify bucket 0/1/31/32"
actual_output="$(LD_LIBRARY_PATH="${build_dir}:${LD_LIBRARY_PATH:-}" \
    "${build_dir}/c_abi_call")" || {
  echo "FAIL: c_abi_call exited with code $? (check LD_LIBRARY_PATH and shared library)" >&2
  exit 1
}
echo "${actual_output}"

expected="0
1
2147483647
4294967295"

if [[ "${actual_output}" != "${expected}" ]]; then
  echo "FAIL: output mismatch" >&2
  echo "Expected:" >&2
  echo "${expected}" >&2
  exit 1
fi

echo
echo "All boundary values match. C ABI experiment passed."
