#!/usr/bin/env bash
set -euo pipefail
# Profile the release configuration with perf and render a flamegraph.
#
# Usage: profile.sh [lines] [services]
# Requires perf and, for the SVG, stackcollapse-perf.pl and flamegraph.pl
# from https://github.com/brendangregg/FlameGraph on PATH.
# Output: build/benchmark/flamegraph-<lines>-<services>.svg

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lines="${1:-1000000}"
services="${2:-1000}"
out="${root_dir}/build/benchmark"
binary="${root_dir}/build/profile/loglens"
input="${out}/profile-${lines}-${services}.log"
data="${out}/perf-${lines}-${services}.data"

if [[ ! "${lines}" =~ ^[1-9][0-9]*$ || ! "${services}" =~ ^[1-9][0-9]*$ ]]; then
  echo "lines and services must be positive integers" >&2
  exit 2
fi
command -v perf >/dev/null || { echo "perf is required" >&2; exit 2; }

# Same flags as the release build, plus symbols and frame pointers. A separate
# output keeps build/release/loglens identical to the benchmarked binary.
make -C "${root_dir}" build/benchmark/generate >/dev/null
mkdir -p "$(dirname "${binary}")" "${out}"
cd "${root_dir}"
${CXX:-g++} -Iinclude -std=c++23 -Wall -Wextra -Wpedantic -Wconversion \
  -Wshadow -O3 -DNDEBUG -g -fno-omit-frame-pointer \
  src/parser.cpp src/aggregator.cpp src/input.cpp src/c_api.cpp src/main.cpp \
  -o "${binary}"

# A file input keeps the generator out of the profile.
./build/benchmark/generate "${lines}" "${services}" >"${input}"
perf record -F 999 --call-graph dwarf -o "${data}" \
  "${binary}" --input "${input}" --max-services "${services}" >/dev/null
perf report -i "${data}" --no-children --sort symbol --stdio 2>/dev/null |
  grep -E '^ +[0-9]+\.[0-9]+%' | head -n 10

if command -v stackcollapse-perf.pl >/dev/null &&
  command -v flamegraph.pl >/dev/null; then
  perf script -i "${data}" | stackcollapse-perf.pl |
    flamegraph.pl --title "loglens ${lines} lines x ${services} services" \
      >"${out}/flamegraph-${lines}-${services}.svg"
  echo "Wrote ${out}/flamegraph-${lines}-${services}.svg"
fi
rm -f "${input}"
