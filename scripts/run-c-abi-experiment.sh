#!/usr/bin/env bash
# C ABI experiment (issue #20): build the C++ `extern "C"` seam as a shared
# library, call it from a Carbon executable, and check the symbol table, the
# lowered call signature, and the 0/1/31/32 boundary buckets.
#
# Prerequisite: ./scripts/bootstrap-carbon.sh
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
carbon="${root_dir}/.tools/carbon_toolchain-${version}/bin/carbon"
loglens_dir="${root_dir}/product/loglens"
source="${loglens_dir}/carbon_experiments/c_abi_call.carbon"
build_dir="${root_dir}/build/c-abi-experiment"
library="${build_dir}/libloglens_c_api.so"
object="${build_dir}/c_abi_call.o"
executable="${build_dir}/c_abi_call"

if [[ ! -x "${carbon}" ]]; then
  echo "Carbon toolchain is missing. Run ./scripts/bootstrap-carbon.sh first." >&2
  exit 2
fi

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

rm -rf "${build_dir}"
mkdir -p "${build_dir}"
"${carbon}" version

echo "==> Build the C++ shared library"
# bucket_upper is constexpr in aggregator.hpp, so c_api.cpp is the whole seam.
"${CXX:-g++}" -std=c++23 -I"${loglens_dir}/include" -O2 -DNDEBUG \
  -shared -fPIC "${loglens_dir}/src/c_api.cpp" -o "${library}"
nm -D --defined-only "${library}" | grep -w loglens_bucket_upper |
  tee "${build_dir}/nm-library.txt"
grep -Eq '^[0-9a-f]+ T loglens_bucket_upper$' "${build_dir}/nm-library.txt" ||
  fail "libloglens_c_api.so does not export loglens_bucket_upper as a text symbol"

echo "==> Compile Carbon against loglens/c_api.h"
"${carbon}" compile --output-last-input-only \
  --clang-arg=-I"${loglens_dir}/include" --output="${object}" "${source}"

echo "==> Lowered C call signature"
"${carbon}" compile --output-last-input-only --phase=lower --dump-llvm-ir \
  --clang-arg=-I"${loglens_dir}/include" "${source}" >"${build_dir}/c_abi_call.ll"
grep -E '^declare .*@loglens_bucket_upper\(' "${build_dir}/c_abi_call.ll" |
  tee "${build_dir}/llvm-declare.txt"
# uint32_t -> i32 argument, uint64_t -> i64 return, unmangled C name.
grep -Eq '^declare i64 @loglens_bucket_upper\(i32( noundef)?\)' \
  "${build_dir}/llvm-declare.txt" ||
  fail "unexpected lowered signature for loglens_bucket_upper"

echo "==> Link the Carbon executable against the shared library"
# shellcheck disable=SC2016 # $ORIGIN is expanded by the dynamic loader.
"${carbon}" link --output="${executable}" "${object}" -- \
  -L"${build_dir}" -lloglens_c_api '-Wl,-rpath,$ORIGIN'
nm -D --undefined-only "${executable}" | grep -w loglens_bucket_upper |
  tee "${build_dir}/nm-executable.txt"
grep -Eq '^ +U loglens_bucket_upper$' "${build_dir}/nm-executable.txt" ||
  fail "c_abi_call does not import loglens_bucket_upper dynamically"

echo "==> Run and compare the boundary buckets"
"${executable}" | tee "${build_dir}/output.txt"
expected="0 0
1 1
31 2147483647
32 4294967295"
if [[ "$(<"${build_dir}/output.txt")" != "${expected}" ]]; then
  printf 'Expected:\n%s\n' "${expected}" >&2
  fail "boundary values differ from LatencyHistogram::bucket_upper"
fi

echo "C ABI experiment passed."
