#!/usr/bin/env bash
set -euo pipefail

binary="${1:?usage: integration.sh BINARY}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

valid='2026-07-12T01:00:00Z INFO api 17 200'
printf '%s\n' "${valid}" >"${tmp_dir}/one.log"
printf '%s\n%s\n%s\n' \
  '2026-07-12T01:00:00Z INFO worker 8 200' \
  '2026-07-12T01:00:01Z ERROR api 20 500' \
  '2026-07-12T01:00:02Z INFO api 10 200' >"${tmp_dir}/many.log"

"${binary}" --input /dev/null >"${tmp_dir}/zero.json"
"${binary}" --input "${tmp_dir}/one.log" >"${tmp_dir}/one.json"
"${binary}" --input "${tmp_dir}/many.log" >"${tmp_dir}/many.json"
diff -u "${script_dir}/golden/zero.json" "${tmp_dir}/zero.json"
diff -u "${script_dir}/golden/one-service.json" "${tmp_dir}/one.json"
diff -u "${script_dir}/golden/many-services.json" "${tmp_dir}/many.json"
for report in "${tmp_dir}"/{zero,one,many}.json; do
  jq -e '.schema_version == 1 and (.services | type == "array")' \
    "${report}" >/dev/null
done

"${binary}" --input "${tmp_dir}/many.log" >"${tmp_dir}/many-repeat.json"
diff -u "${tmp_dir}/many.json" "${tmp_dir}/many-repeat.json"

printf '%s\n' "${valid}" | "${binary}" --input - >"${tmp_dir}/stdin.json"
diff -u "${script_dir}/golden/one-service.json" "${tmp_dir}/stdin.json"

"${binary}" --version | grep -qx 'loglens 1.3.0'
"${binary}" --help >/dev/null

expect_exit() {
  local expected="$1"
  shift
  set +e
  "$@" >"${tmp_dir}/stdout" 2>"${tmp_dir}/stderr"
  local actual=$?
  set -e
  if [[ "${actual}" -ne "${expected}" ]]; then
    echo "expected exit ${expected}, got ${actual}: $*" >&2
    return 1
  fi
}

expect_exit 2 "${binary}" --input - --input -
expect_exit 3 "${binary}" --input "${tmp_dir}/missing"
printf '%s\n' bad | expect_exit 4 "${binary}" --input - --strict
printf '%s\n' "${valid}" | expect_exit 5 "${binary}" --input - --max-line-bytes 8
printf '%s\n%s\n' "${valid}" \
  '2026-07-12T01:00:01Z INFO worker 18 200' |
  expect_exit 5 "${binary}" --input - --max-services 1

if [[ -e /dev/full ]]; then
  set +e
  "${binary}" --input "${tmp_dir}/one.log" >/dev/full 2>"${tmp_dir}/full.stderr"
  full_exit=$?
  set -e
  [[ "${full_exit}" -eq 3 ]]
  grep -q 'write error' "${tmp_dir}/full.stderr"
fi

for index in $(seq 1 2000); do
  printf '2026-07-12T01:00:00Z INFO service-%s 1 200\n' "${index}"
done >"${tmp_dir}/large-output.log"
set +e
"${binary}" --input "${tmp_dir}/large-output.log" 2>"${tmp_dir}/pipe.stderr" |
  head -c 0 >/dev/null
pipe_exit=$?
set -e
[[ "${pipe_exit}" -eq 3 ]]
grep -q 'write error' "${tmp_dir}/pipe.stderr"

printf 'integration tests passed\n'
