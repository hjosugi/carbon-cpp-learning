#!/usr/bin/env bash
# Verify the reference kata solutions in hands-on/carbon/solutions against the
# pinned Carbon nightly:
#   - every NAME.carbon with a NAME.expected file must compile, link, run, and
#     print exactly NAME.expected;
#   - every expect-error/NAME.carbon must be rejected by the check phase with
#     the diagnostic in expect-error/NAME.expected-error.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
carbon="${root_dir}/.tools/carbon_toolchain-${version}/bin/carbon"
# Relative paths keep diagnostics readable and independent of the checkout.
cd "${root_dir}"
source_dir="hands-on/carbon/solutions"
build_dir="build/carbon-katas"

if [[ ! -x "${carbon}" ]]; then
  echo "Carbon toolchain is missing. Run ./scripts/bootstrap-carbon.sh first." >&2
  exit 2
fi

rm -rf "${build_dir}"
mkdir -p "${build_dir}"
failures=0

for expected in "${source_dir}"/*.expected; do
  source="${expected%.expected}.carbon"
  name="$(basename "${source}" .carbon)"
  echo "==> ${name}"
  "${carbon}" compile --output-last-input-only \
    --output="${build_dir}/${name}.o" "${source}"
  "${carbon}" link --output="${build_dir}/${name}" "${build_dir}/${name}.o"
  "${build_dir}/${name}" >"${build_dir}/${name}.out"
  if diff -u "${expected}" "${build_dir}/${name}.out"; then
    cat "${build_dir}/${name}.out"
  else
    echo "FAIL: ${name} output differs from ${expected}" >&2
    failures=$((failures + 1))
  fi
done

for expected in "${source_dir}"/expect-error/*.expected-error; do
  source="${expected%.expected-error}.carbon"
  name="expect-error/$(basename "${source}" .carbon)"
  echo "==> ${name}"
  if "${carbon}" compile --phase=check "${source}" \
    >"${build_dir}/$(basename "${source}").log" 2>&1; then
    echo "FAIL: ${name} compiled, but it must be rejected" >&2
    failures=$((failures + 1))
  elif grep -qF -- "$(<"${expected}")" "${build_dir}/$(basename "${source}").log"; then
    grep -F -- "$(<"${expected}")" "${build_dir}/$(basename "${source}").log"
  else
    echo "FAIL: ${name} did not report: $(<"${expected}")" >&2
    cat "${build_dir}/$(basename "${source}").log" >&2
    failures=$((failures + 1))
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  echo "${failures} kata check(s) failed." >&2
  exit 1
fi
echo "Carbon katas passed."
