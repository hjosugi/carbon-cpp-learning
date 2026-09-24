#!/usr/bin/env bash
# Verify the Carbon side of the C++ comparison labs in
# hands-on/carbon/comparisons against the pinned Carbon nightly:
#   - every NAME.carbon with a NAME.expected file must compile, link, run, and
#     print exactly NAME.expected (with NAME.input on stdin when it exists);
#   - every expect-error/NAME.carbon must be rejected by the check phase, and
#     every line of expect-error/NAME.expected-error must appear in the
#     diagnostics. These files are design-only code or deliberate mistakes.
# The C++ side is checked by `make -C hands-on/cpp test diagnostics`.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
carbon="${root_dir}/.tools/carbon_toolchain-${version}/bin/carbon"
# Relative paths keep diagnostics readable and independent of the checkout.
cd "${root_dir}"
source_dir="hands-on/carbon/comparisons"
build_dir="build/carbon-comparisons"

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
  input="${source%.carbon}.input"
  [[ -f "${input}" ]] || input=/dev/null
  "${build_dir}/${name}" <"${input}" >"${build_dir}/${name}.out"
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
  log="${build_dir}/$(basename "${source}").log"
  echo "==> ${name}"
  if "${carbon}" compile --phase=check "${source}" >"${log}" 2>&1; then
    echo "FAIL: ${name} compiled, but it must be rejected" >&2
    failures=$((failures + 1))
    continue
  fi
  while IFS= read -r line; do
    if grep -qF -- "${line}" "${log}"; then
      echo "${line}"
    else
      echo "FAIL: ${name} did not report: ${line}" >&2
      cat "${log}" >&2
      failures=$((failures + 1))
    fi
  done <"${expected}"
done

if [[ "${failures}" -ne 0 ]]; then
  echo "${failures} comparison check(s) failed." >&2
  exit 1
fi
echo "Carbon comparison labs passed."
