#!/usr/bin/env bash
set -euo pipefail
# Record the machine and toolchain that produced a benchmark run, next to the
# resource reports, so every result can be traced to the hardware it ran on.

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-${root_dir}/build/benchmark/resource-machine.txt}"
mkdir -p "$(dirname "${output}")"

{
  echo "date_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "kernel=$(uname -srm)"
  if [[ -r /etc/os-release ]]; then
    echo "os=$(. /etc/os-release && echo "${PRETTY_NAME}")"
  fi
  echo "cpus=$(nproc)"
  lscpu | grep -E '^(Model name|Thread\(s\) per core|Core\(s\) per socket)'
  grep -E '^MemTotal' /proc/meminfo
  echo "compiler=$(${CXX:-g++} --version | head -n 1)"
  echo "flags=-std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -O3 -DNDEBUG"
} | tee "${output}"
