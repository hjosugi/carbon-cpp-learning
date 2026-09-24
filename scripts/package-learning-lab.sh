#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
parent_dir="$(dirname "${root_dir}")"
archive_name="carbon-cpp-learning-2026-09-25.zip"
archive_path="${parent_dir}/${archive_name}"

rm -f "${archive_path}"
(
  cd "${parent_dir}"
  zip -q -r "${archive_path}" "$(basename "${root_dir}")" \
    -x '*/.git/*' '*/.tools/*' '*/build/*' '*/dist/*'
)
unzip -tq "${archive_path}" >/dev/null
# Record the bare file name so `sha256sum -c` works next to the download.
(cd "${parent_dir}" && sha256sum "${archive_name}") >"${archive_path}.sha256"
echo "Created ${archive_path}"
