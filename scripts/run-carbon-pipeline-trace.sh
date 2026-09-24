#!/usr/bin/env bash
# Carbon toolchain pipeline trace (issue #27).
#
# Dumps every phase of hands-on/carbon/pipeline-trace/add.carbon into
# build/pipeline-trace/, then checks which phase owns each diagnostic: an
# error file must pass `--phase=<previous>` and fail `--phase=<owner>` with
# the expected message.
#
# Prerequisite: ./scripts/bootstrap-carbon.sh
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
toolchain="${root_dir}/.tools/carbon_toolchain-${version}"
carbon="${toolchain}/bin/carbon"

if [[ ! -x "${carbon}" ]]; then
  echo "Carbon toolchain is missing. Run ./scripts/bootstrap-carbon.sh first." >&2
  exit 2
fi

# Relative paths keep dumps and diagnostics independent of the checkout.
cd "${root_dir}/hands-on/carbon/pipeline-trace"
out="${root_dir}/build/pipeline-trace"
rm -rf "${out}"
mkdir -p "${out}"
# Leave the Core prelude out of the dumps; it is imported implicitly.
exclude_core="--exclude-dump-file-prefix=${toolchain}/lib/carbon/core"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

"${carbon}" version | tee "${out}/version.txt"
"${carbon}" help >"${out}/help.txt"
"${carbon}" compile --help >"${out}/compile-help.txt"

echo "==> Trace add.carbon"
"${carbon}" compile --phase=lex --dump-tokens add.carbon >"${out}/tokens.txt"
"${carbon}" compile --phase=parse --dump-parse-tree add.carbon \
  >"${out}/parse-tree.txt"
"${carbon}" compile --phase=check --dump-sem-ir "${exclude_core}" add.carbon \
  >"${out}/sem-ir.txt"
"${carbon}" compile --phase=lower --dump-llvm-ir "${exclude_core}" add.carbon \
  >"${out}/llvm-ir.txt"
# `--dump-asm` prints nothing in the pinned nightly; `--output=-` writes the
# same codegen result as textual assembly instead.
"${carbon}" compile --output-last-input-only --output=- add.carbon \
  >"${out}/asm.s"
"${carbon}" compile --output-last-input-only --output="${out}/add.o" add.carbon
nm "${out}/add.o" | tee "${out}/nm.txt"

# Each phase must carry the construct forward: the `+` token, its parse
# node, the AddWith impl call in SemIR, and a single LLVM `add i32`.
grep -q '"Plus"' "${out}/tokens.txt" || fail "no Plus token"
grep -q "InfixOperatorPlus" "${out}/parse-tree.txt" || fail "no InfixOperatorPlus node"
grep -q "Int.as.AddWith.impl.Op.call" "${out}/sem-ir.txt" || fail "no AddWith call in SemIR"
grep -Eq 'add i32 %a, %b' "${out}/llvm-ir.txt" || fail "no add i32 in LLVM IR"
grep -Eq '^_CAdd\.PipelineTrace:' "${out}/asm.s" || fail "no _CAdd.PipelineTrace in assembly"
grep -Eq ' T _CAdd\.PipelineTrace$' "${out}/nm.txt" || fail "no _CAdd.PipelineTrace symbol"

# check_owner FILE PREVIOUS_PHASE OWNER_PHASE MESSAGE
check_owner() {
  local file="$1" previous="$2" owner="$3" message="$4"
  local log="${out}/${file%.carbon}-${owner}.txt"
  echo "==> ${file}: expected owner phase ${owner}"
  if [[ -n "${previous}" ]] &&
    ! "${carbon}" compile --phase="${previous}" "${file}" \
      >"${out}/${file%.carbon}-${previous}.txt" 2>&1; then
    cat "${out}/${file%.carbon}-${previous}.txt" >&2
    fail "${file} already fails in the ${previous} phase"
  fi
  if "${carbon}" compile --phase="${owner}" "${file}" >"${log}" 2>&1; then
    fail "${file} passes the ${owner} phase"
  fi
  grep -F -- "${message}" "${log}" || fail "${file}: missing '${message}'"
}

check_owner lex-error.carbon "" lex \
  "error: invalid digit 'G' in hexadecimal numeric literal"
check_owner syntax-error.carbon lex parse \
  'error: `return` statements must end with a `;`'
check_owner type-error.carbon parse check \
  'error: cannot implicitly convert expression of type `f64` to `i32`'

echo "Pipeline trace passed. Dumps are in ${out#"${root_dir}/"}."
