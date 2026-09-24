#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lines="${1:-1000000}"
services="${2:-1000}"
report="${3:-${root_dir}/build/benchmark/resource-${lines}-${services}.txt}"

if [[ ! "${lines}" =~ ^[1-9][0-9]*$ || ! "${services}" =~ ^[1-9][0-9]*$ ]]; then
  echo "lines and services must be positive integers" >&2
  exit 2
fi
if [[ ! -x /usr/bin/time ]]; then
  echo "/usr/bin/time is required for peak RSS evidence" >&2
  exit 2
fi

make -C "${root_dir}" build/benchmark/generate release >/dev/null
mkdir -p "$(dirname "${report}")"

# Time only the loglens process so CPU and peak RSS are not mixed with the
# generator. --max-services matches the cardinality under test: the default
# limit (10,000) would otherwise fail closed on the 100,000-service case.
"${root_dir}/build/benchmark/generate" "${lines}" "${services}" |
  /usr/bin/time -v -o "${report}" \
    "${root_dir}/build/release/loglens" --input - \
    --max-services "${services}" >/dev/null

elapsed_str=$(grep 'Elapsed (wall clock)' "${report}" | awk '{print $NF}')
elapsed_sec=$(awk -F: '{if(NF==3){print $1*3600+$2*60+$3}else if(NF==2){print $1*60+$2}else{print $1}}' \
  <<< "${elapsed_str}")
throughput=$(awk -v lines="${lines}" -v elapsed="${elapsed_sec}" \
  'BEGIN{if(elapsed>0)printf "%.0f",lines/elapsed;else print 0}')

{
  echo "lines=${lines}"
  echo "services=${services}"
  grep -E 'User time|System time|Percent of CPU|Elapsed \(wall clock\)|Maximum resident set size|Exit status' "${report}"
  echo "throughput_lines_per_sec=${throughput}"
} | tee "${report}.summary"
