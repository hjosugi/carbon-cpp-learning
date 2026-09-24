#!/usr/bin/env bash
set -euo pipefail
# Check the summaries written by bench_matrix.sh against regression thresholds.
#
# Usage: check_regression.sh [lines]
#
# Peak RSS limits do not depend on the line count: aggregation state is
# O(unique services) and O(1) in input length, so a 100M-line soak must stay
# under the same limit as a 1M-line run. CPU limits (loglens user + system
# time) are per million lines and scale linearly with the line count. CPU time
# is used rather than wall-clock time so that waiting on the generator or a
# busy runner does not count against loglens.
#
# The limits are about 2x the peak RSS and 5x the CPU time measured on the
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

# check SERVICES RSS_LIMIT_KB CPU_SECONDS_PER_MILLION_LINES
check() {
  local services="$1" rss_limit="$2" seconds_per_million="$3"
  local summary="${root_dir}/build/benchmark/resource-${lines}-${services}.txt.summary"
  local label="lines=${lines} services=${services}"

  if [[ ! -f "${summary}" ]]; then
    report FAIL "missing ${summary} (${label})"
    return
  fi

  local exit_status rss user_sec system_sec cpu_sec cpu_limit
  exit_status="$(field "${summary}" '^[[:space:]]*Exit status')"
  rss="$(field "${summary}" 'Maximum resident set size')"
  user_sec="$(field "${summary}" 'User time \(seconds\)')"
  system_sec="$(field "${summary}" 'System time \(seconds\)')"
  cpu_sec="$(awk -v u="${user_sec}" -v s="${system_sec}" \
    'BEGIN { if (u != "" && s != "") printf "%.2f", u + s }')"
  cpu_limit="$(awk -v l="${lines}" -v s="${seconds_per_million}" \
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

  if awk -v c="${cpu_sec}" -v lim="${cpu_limit}" \
    'BEGIN { exit !(c != "" && c <= lim) }'; then
    report OK "cpu=${cpu_sec}s <= ${cpu_limit}s (${label})"
  else
    report FAIL "cpu=${cpu_sec:-missing}s > ${cpu_limit}s (${label})"
  fi
}

# Baseline on ubuntu-24.04 (4 vCPU AMD EPYC 7763, GCC 13.3), 1M lines,
# peak RSS / CPU: 1 service 3,832 kB / 1.33 s, 1,000 services
# 4,376 kB / 1.47 s, 100,000 services 87,796 kB / 1.64 s.
#     services  rss_kB  cpu_s/1M lines
check 1         8000    7
check 1000      9000    7
check 100000    180000  8

exit "${rc}"
