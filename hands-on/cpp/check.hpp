#pragma once

// Minimal assertion helper shared by the comparison lab tests. It stays
// active under NDEBUG, unlike assert().

#include <cstdlib>
#include <iostream>

namespace compare {

inline void check(bool condition, const char* expression, const char* file,
                  int line) {
  if (!condition) {
    std::cerr << "FAIL " << file << ':' << line << ": " << expression << '\n';
    std::exit(1);
  }
}

}  // namespace compare

#define CHECK(expression) \
  ::compare::check((expression), #expression, __FILE__, __LINE__)
