// Expected to fail: a new alternative (Overflow) was added to ParseEvent, but
// this visitor was not updated. std::visit requires a handler for every
// alternative, so the build breaks at the visitor, like a non-exhaustive
// Carbon `match` would by design.
#include <cstdint>
#include <variant>

#include "errors/parse_result.hpp"

auto report_without_overflow(const compare::ParseEvent& event)
    -> std::int32_t {
  return std::visit(
      compare::Overloaded{
          [](const compare::Ok& ok) { return ok.value; },
          [](const compare::Empty&) { return -1; },
          [](const compare::NotDigit&) { return -2; },
      },
      event);
}
