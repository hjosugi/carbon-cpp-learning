#!/usr/bin/env bash
set -euo pipefail
# Run the resource_report benchmark for 1, 1 000, and 100 000 unique services.
# Usage: bench_matrix.sh [lines]
# Default: 1 000 000 lines.

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lines="${1:-1000000}"

if [[ ! "${lines}" =~ ^[1-9][0-9]*$ ]]; then
  echo "lines must be a positive integer" >&2
  exit 2
fi

for services in 1 1000 100000; do
  echo "=== lines=${lines} services=${services} ==="
  bash "${root_dir}/bench/resource_report.sh" "${lines}" "${services}"
  echo
done
