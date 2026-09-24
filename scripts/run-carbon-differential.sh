#!/usr/bin/env bash
# C++/Carbon differential test for the LogLens histogram core (issue #21).
#
#   1. Build the C++ oracle (product/loglens/tests/histogram_oracle.cpp).
#   2. Compile and link the Carbon port
#      (product/loglens/carbon_experiments/histogram.carbon).
#   3. Evaluate the same vector files with both and require byte-identical
#      stdout and the same exit code.
#
# Vector sets:
#   boundary   both edges of every bucket and out-of-range buckets (exit 0)
#   malformed  inputs that both sides must reject with exit 2 after printing
#              the same prefix
#
# It also requires expect-error/shift_distance.carbon to be rejected by the
# check phase, the constant form of the shift boundary BucketUpper avoids.
#
# Prerequisite: ./scripts/bootstrap-carbon.sh
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
carbon="${root_dir}/.tools/carbon_toolchain-${version}/bin/carbon"
# Relative paths keep logs readable and independent of the checkout.
cd "${root_dir}"
build_dir="build/carbon-differential"
oracle="product/loglens/build/test/histogram_oracle"
carbon_source="product/loglens/carbon_experiments/histogram.carbon"
carbon_binary="${build_dir}/histogram"

if [[ ! -x "${carbon}" ]]; then
  echo "Carbon toolchain is missing. Run ./scripts/bootstrap-carbon.sh first." >&2
  exit 2
fi

rm -rf "${build_dir}"
mkdir -p "${build_dir}/malformed"
failures=0
"${carbon}" version

echo "==> Build the C++ oracle"
make -C product/loglens --no-print-directory build/test/histogram_oracle

echo "==> Compile and link the Carbon port"
"${carbon}" compile --output-last-input-only \
  --output="${build_dir}/histogram.o" "${carbon_source}"
"${carbon}" link --output="${carbon_binary}" "${build_dir}/histogram.o"

# compare NAME VECTORS EXPECTED_STATUS
compare() {
  local name="$1" vectors="$2" expected_status="$3"
  local out="${build_dir}/${name}"
  local cpp_status=0 carbon_status=0
  mkdir -p "$(dirname "${out}")"
  "${oracle}" eval <"${vectors}" >"${out}.cpp.out" 2>"${out}.cpp.err" ||
    cpp_status=$?
  "${carbon_binary}" <"${vectors}" >"${out}.carbon.out" || carbon_status=$?

  local vector_count
  vector_count="$(grep -cv '^#' "${vectors}" || true)"
  if [[ "${cpp_status}" -ne "${expected_status}" ]]; then
    echo "FAIL: ${name}: C++ oracle exited ${cpp_status}, expected ${expected_status}" >&2
    failures=$((failures + 1))
  elif [[ "${carbon_status}" -ne "${cpp_status}" ]]; then
    echo "FAIL: ${name}: Carbon exited ${carbon_status}, C++ exited ${cpp_status}" >&2
    failures=$((failures + 1))
  elif ! cmp -s "${out}.cpp.out" "${out}.carbon.out"; then
    echo "FAIL: ${name}: stdout differs" >&2
    diff -u "${out}.cpp.out" "${out}.carbon.out" | head -20 >&2 || true
    failures=$((failures + 1))
  else
    echo "ok ${name}: lines=${vector_count} exit=${cpp_status}" \
      "identical_bytes=$(wc -c <"${out}.cpp.out")"
  fi
}

echo "==> Boundary vectors"
"${oracle}" boundary >"${build_dir}/boundary.vectors"
compare boundary "${build_dir}/boundary.vectors" 0
# The C++ side is pinned by `make test`; the Carbon side must match it too.
if ! cmp -s product/loglens/tests/golden/histogram-boundary.txt \
  "${build_dir}/boundary.carbon.out"; then
  echo "FAIL: boundary: Carbon output differs from tests/golden/histogram-boundary.txt" >&2
  failures=$((failures + 1))
fi

echo "==> Accepted edge input"
printf 'B 007\nL 0000\n# comment\n' >"${build_dir}/leading-zeros.vectors"
compare leading-zeros "${build_dir}/leading-zeros.vectors" 0

echo "==> Malformed input (both must stop with exit 2 after the same prefix)"
malformed() {
  printf '%b' "$2" >"${build_dir}/malformed/$1.vectors"
  compare "malformed/$1" "${build_dir}/malformed/$1.vectors" 2
}
malformed unknown-tag 'L 1\nX 2\nL 3\n'
malformed missing-newline 'L 1\nL 2'
malformed comment-without-newline 'L 1\n# end'
malformed empty-line 'L 1\n\nL 2\n'
malformed crlf 'L 1\r\n'
malformed empty-number 'L \n'
malformed double-space 'L  1\n'
malformed negative 'L -1\n'
malformed trailing-garbage 'B 12x\n'
malformed u32-overflow 'L 4294967296\n'

echo "==> Constant shift distance >= width is rejected in the check phase"
source="product/loglens/carbon_experiments/expect-error/shift_distance.carbon"
expected="$(<"${source%.carbon}.expected-error")"
if "${carbon}" compile --phase=check "${source}" \
  >"${build_dir}/shift_distance.log" 2>&1; then
  echo "FAIL: ${source} compiled, but it must be rejected" >&2
  failures=$((failures + 1))
elif grep -F -- "${expected}" "${build_dir}/shift_distance.log"; then
  :
else
  echo "FAIL: ${source} did not report: ${expected}" >&2
  cat "${build_dir}/shift_distance.log" >&2
  failures=$((failures + 1))
fi

if [[ "${failures}" -ne 0 ]]; then
  echo "${failures} differential check(s) failed." >&2
  exit 1
fi
echo "C++/Carbon differential test passed."
