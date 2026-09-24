#!/usr/bin/env bash
set -euo pipefail
# Check the summaries written by bench_matrix.sh against regression thresholds.
#
# Usage: check_regression.sh [lines]
#
# Peak RSS limits do not depend on the line count: aggregation state is
# O(unique services) and O(1) in input length, so a 100M-line soak must stay
# under the same limit as a 1M-line run. Elapsed limits are per million lines
# and scale linearly with the line count.
#
# The limits are about 2x the peak RSS and 5x the elapsed time measured on the
# GitHub-hosted ubuntu-24.04 runner (docs/evidence/benchmark-report.md), wide
# enough for runner noise while still catching an O(lines) memory leak or a
# per-record slowdown.

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lines="${1:-1000000}"
rc=0

if [[ ! "${lines}" =~ ^[1-9][0-9]*$ ]]; then
  echo "lines must be a positive integer" >&2
  exit 2
fi

field() {
  local summary="$1" pattern="$2"
  grep -E "${pattern}" "${summary}" | awk '{print $NF}'
}

report() {
  local status="$1"
  shift
  if [[ "${status}" == "FAIL" ]]; then
    printf 'FAIL %s\n' "$*" >&2
    rc=1
  else
    printf 'OK   %s\n' "$*"
  fi
}

# check SERVICES RSS_LIMIT_KB SECONDS_PER_MILLION_LINES
check() {
  local services="$1" rss_limit="$2" seconds_per_million="$3"
  local summary="${root_dir}/build/benchmark/resource-${lines}-${services}.txt.summary"
  local label="lines=${lines} services=${services}"

  if [[ ! -f "${summary}" ]]; then
    report FAIL "missing ${summary} (${label})"
    return
  fi

  local exit_status rss elapsed_str elapsed_sec elapsed_limit
  exit_status="$(field "${summary}" '^[[:space:]]*Exit status')"
  rss="$(field "${summary}" 'Maximum resident set size')"
  elapsed_str="$(field "${summary}" 'Elapsed \(wall clock\)')"
  elapsed_sec="$(awk -F: '{
    if (NF == 3) { print $1 * 3600 + $2 * 60 + $3 }
    else if (NF == 2) { print $1 * 60 + $2 }
    else { print $1 }
  }' <<<"${elapsed_str}")"
  elapsed_limit="$(awk -v l="${lines}" -v s="${seconds_per_million}" \
    'BEGIN { printf "%.1f", l / 1000000 * s }')"

  if [[ "${exit_status}" == "0" ]]; then
    report OK "exit=0 (${label})"
  else
    report FAIL "exit=${exit_status:-missing} (${label})"
  fi

  if [[ "${rss}" =~ ^[0-9]+$ && "${rss}" -le "${rss_limit}" ]]; then
    report OK "rss=${rss} kB <= ${rss_limit} kB (${label})"
  else
    report FAIL "rss=${rss:-missing} kB > ${rss_limit} kB (${label})"
  fi

  if awk -v e="${elapsed_sec}" -v lim="${elapsed_limit}" \
    'BEGIN { exit !(e != "" && e <= lim) }'; then
    report OK "elapsed=${elapsed_sec}s <= ${elapsed_limit}s (${label})"
  else
    report FAIL "elapsed=${elapsed_sec:-missing}s > ${elapsed_limit}s (${label})"
  fi
}

#     services  rss_kB  s/1M lines
check 1         8000    5
check 1000      8000    5
check 100000    80000   10

exit "${rc}"
