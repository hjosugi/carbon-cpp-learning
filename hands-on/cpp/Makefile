# C++23 side of the Carbon comparison labs (issues #5-#8).
#   make test         build and run every *_test.cpp
#   make diagnostics  check that expect-error/*.cpp are rejected as recorded
CXX ?= g++
CPPFLAGS := -I.
CXXFLAGS := -std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror
BUILD := build/$(notdir $(CXX))

TESTS := counter/counter_test generics/min_test

.PHONY: test diagnostics clean

test: $(TESTS:%=$(BUILD)/%)
	@set -e; for test in $^; do echo "==> $$test"; ./$$test; done

$(BUILD)/%: %.cpp $(wildcard */*.hpp) check.hpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -O2 $< -o $@

diagnostics:
	CXX='$(CXX)' CXXFLAGS='$(CPPFLAGS) $(CXXFLAGS)' bash check-diagnostics.sh

clean:
	rm -rf build
