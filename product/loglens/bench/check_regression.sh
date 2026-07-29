#!/usr/bin/env bash
set -euo pipefail
# Check benchmark summary files against regression thresholds.
#
# Thresholds (lines=1 000 000):
#   services=1        rss < 20 000 kB   elapsed < 60 s
#   services=1 000    rss < 80 000 kB   elapsed < 60 s
#   services=100 000  rss < 500 000 kB  elapsed < 180 s
#
# Limits account for OS buffers, C++ runtime, and unordered_map overhead.
# They scale proportionally with service count (O(services)) to detect
# memory regressions without being sensitive to normal system variance.
#
# Usage: check_regression.sh [lines]

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lines="${1:-1000000}"
rc=0

check() {
  local services="$1"
  local rss_limit="$2"
  local elapsed_limit="$3"
  local summary="${root_dir}/build/benchmark/resource-${lines}-${services}.txt.summary"

  if [[ ! -f "${summary}" ]]; then
    printf 'MISSING %s\n' "${summary}" >&2
    rc=1
    return
  fi

  local rss
  rss=$(grep 'Maximum resident set size' "${summary}" | awk '{print $NF}')

  local elapsed_str
  elapsed_str=$(grep 'Elapsed (wall clock)' "${summary}" | awk '{print $NF}')
  local elapsed_sec
  elapsed_sec=$(awk -F: '{
    if (NF==3) { print $1*3600+$2*60+$3 }
    else if (NF==2) { print $1*60+$2 }
    else { print $1 }
  }' <<< "${elapsed_str}")

  if [[ "${rss}" -gt "${rss_limit}" ]]; then
    printf 'FAIL rss=%s kB > limit=%s kB  (lines=%s services=%s)\n' \
      "${rss}" "${rss_limit}" "${lines}" "${services}" >&2
    rc=1
  else
    printf 'OK   rss=%s kB <= limit=%s kB  (lines=%s services=%s)\n' \
      "${rss}" "${rss_limit}" "${lines}" "${services}"
  fi

  local over_elapsed
  over_elapsed=$(awk -v e="${elapsed_sec}" -v lim="${elapsed_limit}" \
    'BEGIN{print(e>lim)?1:0}')
  if [[ "${over_elapsed}" == "1" ]]; then
    printf 'FAIL elapsed=%ss > limit=%ss  (lines=%s services=%s)\n' \
      "${elapsed_sec}" "${elapsed_limit}" "${lines}" "${services}" >&2
    rc=1
  else
    printf 'OK   elapsed=%ss <= limit=%ss  (lines=%s services=%s)\n' \
      "${elapsed_sec}" "${elapsed_limit}" "${lines}" "${services}"
  fi
}

check 1      20000  60
check 1000   80000  60
check 100000 500000 180

exit "${rc}"
