#!/usr/bin/env bash
# C++/Carbon differential test for the LogLens histogram core (issues #21, #22).
#
#   1. Build the C++ oracle (product/loglens/tests/histogram_oracle.cpp).
#   2. Compile and link the Carbon port
#      (product/loglens/carbon_experiments/histogram.carbon).
#   3. Evaluate the same vector files with both and require byte-identical
#      stdout and the same exit code.
#
# Vector sets:
#   boundary   both edges of every bucket and out-of-range buckets (exit 0)
#   random     COUNT SplitMix64 vectors from SEED (exit 0)
#   malformed  inputs that both sides must reject with exit 2 after printing
#              the same prefix
#
# On a stdout mismatch the first disagreeing vector is shrunk to a one-line
# minimal reproduction in build/carbon-differential/<set>.minimal.vectors.
# It also requires expect-error/shift_distance.carbon to be rejected by the
# check phase, the constant form of the shift boundary BucketUpper avoids.
# Seeds, vector hashes and results are written to
# build/carbon-differential/compare.log.
#
# Usage: run-carbon-differential.sh [--seed N] [--count N]
# Environment:
#   CARBON_VERSION         toolchain to use (default: .carbon-version)
#   CARBON_DIFF_SEED       default seed (20260925)
#   CARBON_DIFF_COUNT      default random vector count (10000)
#   CARBON_DIFF_SOURCE     Carbon file to test instead of histogram.carbon,
#                          for negative controls
#
# Prerequisite: ./scripts/bootstrap-carbon.sh
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
carbon="${root_dir}/.tools/carbon_toolchain-${version}/bin/carbon"
seed="${CARBON_DIFF_SEED:-20260925}"
count="${CARBON_DIFF_COUNT:-10000}"
carbon_source="${CARBON_DIFF_SOURCE:-product/loglens/carbon_experiments/histogram.carbon}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --seed) seed="$2"; shift 2 ;;
    --count) count="$2"; shift 2 ;;
    *) echo "usage: $0 [--seed N] [--count N]" >&2; exit 64 ;;
  esac
done
if [[ ! "${seed}" =~ ^[0-9]+$ || ! "${count}" =~ ^[0-9]+$ ]]; then
  echo "--seed and --count must be decimal integers" >&2
  exit 64
fi

# Relative paths keep logs readable and independent of the checkout.
cd "${root_dir}"
build_dir="build/carbon-differential"
oracle="product/loglens/build/test/histogram_oracle"
carbon_binary="${build_dir}/histogram"
log="${build_dir}/compare.log"

if [[ ! -x "${carbon}" ]]; then
  echo "Carbon toolchain is missing. Run ./scripts/bootstrap-carbon.sh first." >&2
  exit 2
fi

rm -rf "${build_dir}"
mkdir -p "${build_dir}/malformed"
failures=0

# Prints a line and appends it to compare.log.
log() {
  printf '%s\n' "$*" | tee -a "${log}"
}

log "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
log "carbon: $("${carbon}" version)"
log "cxx: $("${CXX:-g++}" --version | head -n 1)"
log "carbon_source: ${carbon_source}"
log "seed: ${seed}"
log "count: ${count}"

echo "==> Build the C++ oracle"
make -C product/loglens --no-print-directory build/test/histogram_oracle

echo "==> Compile and link the Carbon port"
"${carbon}" compile --output-last-input-only \
  --output="${build_dir}/histogram.o" "${carbon_source}"
"${carbon}" link --output="${carbon_binary}" "${build_dir}/histogram.o"

# Succeeds when both implementations print the same bytes and exit with the
# same code for the single vector "TAG VALUE".
agree() {
  local vector="$1 $2" cpp carbon_out cpp_status=0 carbon_status=0
  cpp="$(printf '%s\n' "${vector}" | "${oracle}" eval 2>/dev/null)" ||
    cpp_status=$?
  carbon_out="$(printf '%s\n' "${vector}" | "${carbon_binary}")" ||
    carbon_status=$?
  [[ "${cpp}" == "${carbon_out}" && "${cpp_status}" -eq "${carbon_status}" ]]
}

# shrink NAME VECTORS
# Finds the vector behind the first differing output line and reduces its
# value while the two implementations still disagree: try 0, the power of
# two at or below it (the lower edge of its bucket for L vectors), half of
# it, and one less, until no candidate disagrees.
shrink() {
  local name="$1" vectors="$2" out="${build_dir}/$1" report index vector
  report="$(cmp "${out}.cpp.out" "${out}.carbon.out" 2>&1 || true)"
  if [[ "${report}" =~ differ:\ byte\ [0-9]+,\ line\ ([0-9]+) ]]; then
    index="${BASH_REMATCH[1]}"
  elif [[ "${report}" =~ EOF\ on\ .*\ after\ byte\ [0-9]+,\ line\ ([0-9]+) ]]; then
    index=$((BASH_REMATCH[1] + 1))
  elif [[ "${report}" =~ EOF\ on\ .*\ which\ is\ empty ]]; then
    index=1
  else
    log "shrink ${name}: stdout is identical, nothing to shrink"
    return
  fi
  vector="$(grep -v '^#' "${vectors}" | sed -n "${index}p")"
  if [[ ! "${vector}" =~ ^[LB]\ [0-9]+$ ]]; then
    log "shrink ${name}: vector ${index} is not a well-formed vector: ${vector}"
    return
  fi
  local tag="${vector%% *}" value="${vector#* }" power candidate next
  log "shrink ${name}: first mismatch at vector ${index}: ${vector}"
  if agree "${tag}" "${value}"; then
    log "shrink ${name}: ${vector} agrees on its own; the mismatch needs the preceding lines"
    return
  fi
  while :; do
    power=1
    while ((power * 2 <= value)); do power=$((power * 2)); done
    next=""
    for candidate in 0 "${power}" $((value / 2)) $((value - 1)); do
      if ((candidate < value)) && ! agree "${tag}" "${candidate}"; then
        next="${candidate}"
        break
      fi
    done
    [[ -n "${next}" ]] || break
    value="${next}"
  done
  printf '%s %s\n' "${tag}" "${value}" >"${out}.minimal.vectors"
  log "minimal reproduction (${out}.minimal.vectors): ${tag} ${value}"
  log "  C++:    $("${oracle}" eval <"${out}.minimal.vectors" 2>&1 || true)"
  log "  Carbon: $("${carbon_binary}" <"${out}.minimal.vectors" 2>&1 || true)"
}

# compare NAME VECTORS EXPECTED_STATUS
compare() {
  local name="$1" vectors="$2" expected_status="$3"
  local out="${build_dir}/${name}"
  local cpp_status=0 carbon_status=0
  "${oracle}" eval <"${vectors}" >"${out}.cpp.out" 2>"${out}.cpp.err" ||
    cpp_status=$?
  "${carbon_binary}" <"${vectors}" >"${out}.carbon.out" || carbon_status=$?

  local vector_count
  vector_count="$(grep -cv '^#' "${vectors}" || true)"
  if [[ "${cpp_status}" -ne "${expected_status}" ]]; then
    log "FAIL ${name}: C++ oracle exited ${cpp_status}, expected ${expected_status}"
    failures=$((failures + 1))
  elif ! cmp -s "${out}.cpp.out" "${out}.carbon.out"; then
    log "FAIL ${name}: stdout differs (C++ exit ${cpp_status}, Carbon exit ${carbon_status})"
    diff -u "${out}.cpp.out" "${out}.carbon.out" | head -n 20 >&2 || true
    failures=$((failures + 1))
    shrink "${name}" "${vectors}"
  elif [[ "${carbon_status}" -ne "${cpp_status}" ]]; then
    log "FAIL ${name}: Carbon exited ${carbon_status}, C++ exited ${cpp_status}"
    failures=$((failures + 1))
  else
    log "ok ${name}: lines=${vector_count} exit=${cpp_status}" \
      "identical_bytes=$(wc -c <"${out}.cpp.out")"
  fi
}

# Hash of a file, without the file name.
hash_of() {
  sha256sum "$1" | cut -d' ' -f1
}

echo "==> Boundary vectors"
"${oracle}" boundary >"${build_dir}/boundary.vectors"
log "boundary vectors sha256: $(hash_of "${build_dir}/boundary.vectors")"
compare boundary "${build_dir}/boundary.vectors" 0
# The C++ side is pinned by `make test`; the Carbon side must match it too.
if ! cmp -s product/loglens/tests/golden/histogram-boundary.txt \
  "${build_dir}/boundary.carbon.out"; then
  log "FAIL boundary: Carbon output differs from tests/golden/histogram-boundary.txt"
  failures=$((failures + 1))
fi

echo "==> Random vectors (seed ${seed}, count ${count})"
"${oracle}" random "${seed}" "${count}" >"${build_dir}/random.vectors"
log "random vectors sha256: $(hash_of "${build_dir}/random.vectors")"
compare random "${build_dir}/random.vectors" 0
log "random output sha256: C++ $(hash_of "${build_dir}/random.cpp.out")" \
  "Carbon $(hash_of "${build_dir}/random.carbon.out")"

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
  log "FAIL ${source} compiled, but it must be rejected"
  failures=$((failures + 1))
elif grep -F -- "${expected}" "${build_dir}/shift_distance.log"; then
  log "ok shift_distance: rejected with the expected diagnostic"
else
  log "FAIL ${source} did not report: ${expected}"
  cat "${build_dir}/shift_distance.log" >&2
  failures=$((failures + 1))
fi

if [[ "${failures}" -ne 0 ]]; then
  log "${failures} differential check(s) failed."
  exit 1
fi
log "C++/Carbon differential test passed."
