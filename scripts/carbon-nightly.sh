#!/usr/bin/env bash
# Steps of the Carbon nightly refresh (issue #23), used by
# .github/workflows/carbon-nightly.yml and runnable locally. Each subcommand
# does one thing, so a failed run points at the step that failed:
#
#   latest              print the newest nightly version. It does not look at
#                       the release assets.
#   asset VERSION       check that the VERSION release has the toolchain
#                       archive, that it is uploaded and downloadable, and
#                       print the archive's SHA-256 from the release asset
#                       digest (the value .carbon-sha256 pins).
#   notes FROM TO       print a Markdown summary of the release notes of the
#                       nightlies after FROM up to and including TO.
#
# Needs an authenticated `gh` (GH_TOKEN in GitHub Actions) and curl.
set -euo pipefail

repo="carbon-language/carbon-lang"
nightly_pattern='^0\.0\.0-0\.nightly\.[0-9]{4}\.[0-9]{2}\.[0-9]{2}$'
# Release-note lines that may change syntax or semantics the labs rely on.
syntax_pattern='syntax|keyword|grammar|pars(e|er|ing)|lex|token|rename|replace|remov|deprecat|diagnos'

usage() {
  echo "usage: $0 latest | asset VERSION | notes FROM TO" >&2
  exit 64
}

require_version() {
  if [[ ! "$1" =~ ${nightly_pattern} ]]; then
    echo "not a Carbon nightly version: $1" >&2
    exit 64
  fi
}

latest() {
  local version
  version="$(gh api "repos/${repo}/releases?per_page=30" \
    --jq '[.[] | select(.draft | not) | .tag_name
           | select(test("^v0\\.0\\.0-0\\.nightly\\.[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}$"))]
          | sort | last // empty')"
  if [[ -z "${version}" ]]; then
    echo "no nightly release found in ${repo}" >&2
    exit 1
  fi
  echo "${version#v}"
}

asset() {
  local version="$1" name digest state size url
  require_version "${version}"
  name="carbon_toolchain-${version}.tar.gz"
  # One line: "<state> <size> <digest> <url>", or nothing if the asset is missing.
  local record
  if ! record="$(gh api "repos/${repo}/releases/tags/v${version}" \
    --jq ".assets[] | select(.name == \"${name}\")
          | \"\(.state) \(.size) \(.digest // \"none\") \(.browser_download_url)\"")"; then
    echo "release v${version} was not found in ${repo}" >&2
    exit 1
  fi
  if [[ -z "${record}" ]]; then
    echo "release v${version} has no asset ${name}" >&2
    exit 1
  fi
  read -r state size digest url <<<"${record}"
  if [[ "${state}" != "uploaded" || "${size}" -le 0 ]]; then
    echo "asset ${name} is not ready: state=${state} size=${size}" >&2
    exit 1
  fi
  if [[ ! "${digest}" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "asset ${name} has no SHA-256 digest (${digest})" >&2
    exit 1
  fi
  # The asset record can exist before the file is served; follow the redirect.
  if ! curl --proto '=https' --tlsv1.2 --silent --fail --location --head \
    --retry 3 --output /dev/null "${url}"; then
    echo "asset ${name} is listed but not downloadable: ${url}" >&2
    exit 1
  fi
  echo "${digest#sha256:}"
}

notes() {
  local from="$1" to="$2" releases count
  require_version "${from}"
  require_version "${to}"
  # Tags are zero-padded dates, so string order is release order.
  releases="$(gh api --paginate "repos/${repo}/releases?per_page=100" \
    --jq ".[] | select(.draft | not)
         | select(.tag_name > \"v${from}\" and .tag_name <= \"v${to}\")
         | select(.tag_name | test(\"^v0\\\\.0\\\\.0-0\\\\.nightly\\\\.\"))
         | {tag: .tag_name, body: (.body // \"\")} | @json")"
  count="$(grep -c . <<<"${releases}" || true)"

  echo "## Carbon release notes: ${from} → ${to}"
  echo
  echo "${count} nightly release(s) after \`${from}\`." \
    "Full changelog: https://github.com/${repo}/compare/v${from}...v${to}"
  echo
  if [[ "${count}" -eq 0 ]]; then
    return
  fi

  # "<section>\t<entry>" for every bullet, oldest release first.
  local entries
  entries="$(jq -r '
      .body | split("\n") as $lines
      | reduce $lines[] as $line ({section: "Other", out: []};
          if ($line | startswith("### ")) then
            .section = ($line | ltrimstr("### ") | sub(" :[a-z_]+:$"; ""))
          elif ($line | startswith("* ")) then
            .out += ["\(.section)\t\($line | ltrimstr("* "))"]
          else . end)
      | .out[]' <<<"$(sort <<<"${releases}")")"

  echo "| Section | Entries |"
  echo "| --- | ---: |"
  cut -f1 <<<"${entries}" | sort | uniq -c | sort -rn |
    while read -r n section; do echo "| ${section} | ${n} |"; done
  echo

  echo "### Proposals accepted and merged"
  echo
  list_entries "$(grep -F "Proposals accepted" <<<"${entries}" | cut -f2- || true)"

  echo "### Toolchain changes that may affect syntax or diagnostics"
  echo
  echo "Toolchain entries matching \`${syntax_pattern}\` (case-insensitive)."
  echo
  list_entries "$(grep -F "Toolchain and implementation" <<<"${entries}" |
    cut -f2- | grep -Ei "${syntax_pattern}" || true)"
}

# Prints up to 40 Markdown bullets and a count of the rest.
list_entries() {
  local lines="$1" total
  if [[ -z "${lines}" ]]; then
    echo "None."
    echo
    return
  fi
  total="$(grep -c . <<<"${lines}")"
  head -n 40 <<<"${lines}" | sed 's/^/- /'
  if [[ "${total}" -gt 40 ]]; then
    echo "- … and $((total - 40)) more (see the full changelog)"
  fi
  echo
}

case "${1:-}" in
  latest) [[ $# -eq 1 ]] || usage; latest ;;
  asset) [[ $# -eq 2 ]] || usage; asset "$2" ;;
  notes) [[ $# -eq 3 ]] || usage; notes "$2" "$3" ;;
  *) usage ;;
esac
