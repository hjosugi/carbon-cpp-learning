CXX ?= g++
EXTRA_CXXFLAGS ?=
FUZZ_SECONDS ?= 600
LINES ?= 1000000
CPPFLAGS := -Iinclude
CXXFLAGS := -std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow $(EXTRA_CXXFLAGS)
SOURCES := src/parser.cpp src/aggregator.cpp src/input.cpp src/c_api.cpp

.PHONY: all release debug test integration histogram-oracle sanitize fuzz fuzz-build fuzz-long benchmark resource-report bench-matrix check-regression warnings clean

all: release

release: build/release/loglens

debug: build/debug/loglens

build/release/loglens: $(SOURCES) src/main.cpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -O3 -DNDEBUG $^ -o $@

build/debug/loglens: $(SOURCES) src/main.cpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -O0 -g3 $^ -o $@

build/test/loglens_tests: $(SOURCES) tests/test_main.cpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -O2 $^ -o $@

build/test/histogram_oracle: tests/histogram_oracle.cpp include/loglens/aggregator.hpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -O2 $< -o $@

test: build/test/loglens_tests
	./build/test/loglens_tests
	$(MAKE) histogram-oracle
	$(MAKE) integration

# The C++ reference for the Carbon histogram port must keep producing the
# recorded bucket-edge results (scripts/run-carbon-differential.sh).
histogram-oracle: build/test/histogram_oracle
	./build/test/histogram_oracle boundary >build/test/histogram-boundary.vectors
	./build/test/histogram_oracle eval <build/test/histogram-boundary.vectors \
		>build/test/histogram-boundary.txt
	diff -u tests/golden/histogram-boundary.txt build/test/histogram-boundary.txt

integration: build/debug/loglens build/release/loglens
	bash tests/integration.sh ./build/debug/loglens
	bash tests/integration.sh ./build/release/loglens

sanitize:
	@mkdir -p build/sanitize
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -O1 -g3 -fno-omit-frame-pointer \
		-fsanitize=address,undefined $(SOURCES) tests/test_main.cpp \
		-o build/sanitize/loglens_tests
	ASAN_OPTIONS=detect_leaks=$${ASAN_DETECT_LEAKS:-0} ./build/sanitize/loglens_tests

fuzz-build:
	@mkdir -p build/fuzz
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -O1 -g3 -fno-omit-frame-pointer \
		-fsanitize=fuzzer,address,undefined src/parser.cpp tests/fuzz_parser.cpp \
		-o build/fuzz/fuzz_parser

fuzz: fuzz-build
	@rm -rf build/fuzz/corpus
	@mkdir -p build/fuzz/corpus
	@cp -R tests/corpus/. build/fuzz/corpus/
	./build/fuzz/fuzz_parser -artifact_prefix=build/fuzz/ -runs=10000 build/fuzz/corpus

fuzz-long: fuzz-build
	@rm -rf build/fuzz/corpus
	@mkdir -p build/fuzz/corpus
	@cp -R tests/corpus/. build/fuzz/corpus/
	./build/fuzz/fuzz_parser -artifact_prefix=build/fuzz/ \
		-max_total_time=$(FUZZ_SECONDS) build/fuzz/corpus

build/benchmark/generate: bench/generate.cpp
	@mkdir -p $(@D)
	$(CXX) $(CXXFLAGS) -O3 -DNDEBUG $< -o $@

benchmark: build/benchmark/generate build/release/loglens
	./build/benchmark/generate 100000 1000 | ./build/release/loglens --input - >/dev/null

bench-matrix: build/benchmark/generate build/release/loglens
	bash bench/bench_matrix.sh $(LINES)

check-regression:
	bash bench/check_regression.sh $(LINES)

resource-report:
	bash bench/resource_report.sh

warnings:
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Werror -fsyntax-only $(SOURCES) src/main.cpp \
		tests/histogram_oracle.cpp

clean:
	rm -rf build
