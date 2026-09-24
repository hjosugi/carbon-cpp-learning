#!/usr/bin/env bash
# Every expect-error/NAME.cpp must fail to compile, and every line of
# expect-error/NAME.<family>.expected-error must appear in the diagnostics,
# where <family> is gcc or clang. Only short, long-stable message fragments
# are recorded, so GCC 13+ and Clang 18+ report them the same way; the full
# diagnostics are in the evidence docs.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
cxx="${CXX:-g++}"
read -r -a flags <<<"${CXXFLAGS:--I. -std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror}"
if "${cxx}" --version | grep -qi clang; then family=clang; else family=gcc; fi
build_dir="build/$(basename "${cxx}")/expect-error"
mkdir -p "${build_dir}"
"${cxx}" --version | head -n 1
failures=0

for source in expect-error/*.cpp; do
  name="$(basename "${source}" .cpp)"
  expected="expect-error/${name}.${family}.expected-error"
  log="${build_dir}/${name}.log"
  echo "==> ${source} (${family})"
  if [[ ! -f "${expected}" ]]; then
    echo "FAIL: missing ${expected}" >&2
    failures=$((failures + 1))
    continue
  fi
  if "${cxx}" "${flags[@]}" -fsyntax-only "${source}" >"${log}" 2>&1; then
    echo "FAIL: ${source} compiled, but it must be rejected" >&2
    failures=$((failures + 1))
    continue
  fi
  while IFS= read -r line; do
    if grep -qF -- "${line}" "${log}"; then
      echo "${line}"
    else
      echo "FAIL: ${source} did not report: ${line}" >&2
      cat "${log}" >&2
      failures=$((failures + 1))
    fi
  done <"${expected}"
done

if [[ "${failures}" -ne 0 ]]; then
  echo "${failures} C++ diagnostic check(s) failed." >&2
  exit 1
fi
echo "C++ diagnostic checks passed."
