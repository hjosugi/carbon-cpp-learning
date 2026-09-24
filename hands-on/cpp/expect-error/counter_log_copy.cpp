// Expected to fail: CounterLog deletes its copy constructor, so copying it is
// rejected. Carbon reports the same mistake as "cannot copy value of type
// `Counter`" when a class has no `Core.Copy` impl.
#include <cstddef>

#include "counter/counter.hpp"

auto copy_size(const compare::CounterLog& log) -> std::size_t {
  const compare::CounterLog copy = log;
  return copy.size();
}
