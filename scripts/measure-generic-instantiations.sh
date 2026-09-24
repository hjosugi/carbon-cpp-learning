#!/usr/bin/env bash
# Issue #6: measure how a checked generic (Carbon) and a constrained template
# (C++) are compiled when `Min` is called with N distinct types.
#
# For N = 1, 4, 16 the script generates the same program in both languages:
# N one-field classes that implement `Ordered` / specialize `OrderedImpl`, a
# generic `Min`, and one function calling `Min` once per type. It reports:
#   - Min bodies: defined `Min` functions in the object file (nm);
#   - .text bytes: the sum of all .text* section sizes in the object file;
#   - compile s: the best of 3 wall-clock compile times on this machine.
# It is evidence for docs/evidence/checked-generics.md, not a CI gate.
#
# Prerequisite: ./scripts/bootstrap-carbon.sh
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="${CARBON_VERSION:-$(<"${root_dir}/.carbon-version")}"
carbon="${root_dir}/.tools/carbon_toolchain-${version}/bin/carbon"
cxx="${CXX:-g++}"
build_dir="${root_dir}/build/generic-instantiations"

if [[ ! -x "${carbon}" ]]; then
  echo "Carbon toolchain is missing. Run ./scripts/bootstrap-carbon.sh first." >&2
  exit 2
fi

rm -rf "${build_dir}"
mkdir -p "${build_dir}"

generate_carbon() {
  local count="$1"
  echo 'interface Ordered {'
  echo '  fn Less(self, other: Self) -> bool;'
  echo '}'
  for ((index = 1; index <= count; ++index)); do
    cat <<EOF
class T${index} {
  var v: i32;
}
impl T${index} as Core.Copy {
  fn Op(self) -> Self { return {.v = self.v}; }
}
impl T${index} as Ordered {
  fn Less(self, other: Self) -> bool { return self.v < other.v; }
}
EOF
  done
  cat <<'EOF'
fn Min[T: Ordered & Core.Copy](left: T, right: T) -> T {
  if (right.Less(left)) {
    return right;
  }
  return left;
}
fn Sum() -> i32 {
  var total: i32 = 0;
EOF
  for ((index = 1; index <= count; ++index)); do
    echo "  total += Min({.v = ${index}} as T${index}, {.v = 0} as T${index}).v;"
  done
  echo '  return total;'
  echo '}'
}

generate_cpp() {
  local count="$1"
  cat <<'EOF'
#include <concepts>
#include <cstdint>
template <typename T>
struct OrderedImpl;
template <typename T>
concept Ordered = std::copyable<T> && requires(const T& a, const T& b) {
  { OrderedImpl<T>::less(a, b) } -> std::same_as<bool>;
};
EOF
  for ((index = 1; index <= count; ++index)); do
    cat <<EOF
struct T${index} {
  std::int32_t v;
};
template <>
struct OrderedImpl<T${index}> {
  static auto less(const T${index}& a, const T${index}& b) noexcept -> bool {
    return a.v < b.v;
  }
};
EOF
  done
  cat <<'EOF'
template <Ordered T>
auto min_of(const T& left, const T& right) -> T {
  return OrderedImpl<T>::less(right, left) ? right : left;
}
auto sum() -> std::int32_t {
  std::int32_t total = 0;
EOF
  for ((index = 1; index <= count; ++index)); do
    echo "  total += min_of(T${index}{${index}}, T${index}{0}).v;"
  done
  echo '  return total;'
  echo '}'
}

# Prints the best of 3 wall-clock times of "$@" in seconds.
best_of_3() {
  local best="" elapsed
  for _ in 1 2 3; do
    local start end
    start="$(date +%s.%N)"
    "$@" >/dev/null 2>&1
    end="$(date +%s.%N)"
    elapsed="$(awk -v s="${start}" -v e="${end}" 'BEGIN { printf "%.2f", e - s }')"
    if [[ -z "${best}" ]] || awk -v a="${elapsed}" -v b="${best}" 'BEGIN { exit !(a < b) }'; then
      best="${elapsed}"
    fi
  done
  echo "${best}"
}

text_bytes() {
  size -A "$1" | awk '$1 ~ /^\.text/ { total += $2 } END { print total + 0 }'
}

"${carbon}" version
"${cxx}" --version | head -n 1
echo
echo "| N | Toolchain | Min bodies | .text bytes | compile s |"
echo "| ---: | --- | ---: | ---: | ---: |"
for count in 1 4 16; do
  carbon_source="${build_dir}/min_${count}.carbon"
  cpp_source="${build_dir}/min_${count}.cpp"
  generate_carbon "${count}" >"${carbon_source}"
  generate_cpp "${count}" >"${cpp_source}"

  for optimize in none speed; do
    object="${build_dir}/min_${count}_${optimize}.carbon.o"
    compile=("${carbon}" compile --output-last-input-only
      "--optimize=${optimize}" "--output=${object}" "${carbon_source}")
    seconds="$(best_of_3 "${compile[@]}")"
    "${compile[@]}"
    bodies="$(nm --defined-only "${object}" | grep -c '_CMin\.' || true)"
    echo "| ${count} | Carbon --optimize=${optimize} | ${bodies} | $(text_bytes "${object}") | ${seconds} |"
  done

  for level in O0 O2; do
    object="${build_dir}/min_${count}_${level}.cpp.o"
    compile=("${cxx}" -std=c++23 "-${level}" -c "${cpp_source}" -o "${object}")
    seconds="$(best_of_3 "${compile[@]}")"
    "${compile[@]}"
    bodies="$(nm -C --defined-only "${object}" | grep -c ' min_of<' || true)"
    echo "| ${count} | $(basename "${cxx}") -${level} | ${bodies} | $(text_bytes "${object}") | ${seconds} |"
  done
done
