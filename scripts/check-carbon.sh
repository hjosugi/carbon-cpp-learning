#!/usr/bin/env bash
# Run every Carbon check against one toolchain: the pinned nightly by default,
# or a candidate nightly with CARBON_VERSION=... (see
# .github/workflows/carbon-nightly.yml). Runs the C ABI experiment and every
# scripts/run-carbon-*.sh script, keeps going after a failure, and exits 1 if
# any of them failed.
#
# Prerequisite: ./scripts/bootstrap-carbon.sh (with the same CARBON_VERSION)
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=()
for script in "${root_dir}"/scripts/run-carbon-*.sh \
  "${root_dir}/scripts/run-c-abi-experiment.sh"; do
  name="$(basename "${script}")"
  echo "::group::${name}"
  if bash "${script}"; then
    echo "::endgroup::"
    echo "ok ${name}"
  else
    echo "::endgroup::"
    echo "FAIL ${name}" >&2
    failed+=("${name}")
  fi
done

if [[ "${#failed[@]}" -ne 0 ]]; then
  echo "Failed Carbon checks: ${failed[*]}" >&2
  exit 1
fi
echo "All Carbon checks passed."
