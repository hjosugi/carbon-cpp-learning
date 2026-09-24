// Expected to fail under -Wall -Werror: the switch misses the `overflow`
// enumerator. Without -Werror this is only a warning, and without `-Wswitch`
// it is silent, so the std::expected + enum style relies on compiler flags
// for exhaustiveness.
#include <cstdint>

#include "errors/parse_result.hpp"

auto code(compare::ParseErrorCode error) -> std::int32_t {
  switch (error) {
    case compare::ParseErrorCode::empty:
      return 1;
    case compare::ParseErrorCode::not_digit:
      return 2;
  }
  return 0;
}
