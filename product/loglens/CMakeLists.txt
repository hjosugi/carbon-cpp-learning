cmake_minimum_required(VERSION 3.25)
project(loglens VERSION 1.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_library(loglens_core src/parser.cpp src/aggregator.cpp src/input.cpp src/c_api.cpp)
target_include_directories(loglens_core PUBLIC include)
target_compile_options(loglens_core PRIVATE
  -Wall -Wextra -Wpedantic -Wconversion -Wshadow)

add_executable(loglens src/main.cpp)
target_link_libraries(loglens PRIVATE loglens_core)

enable_testing()
add_executable(loglens_tests tests/test_main.cpp)
target_link_libraries(loglens_tests PRIVATE loglens_core)
add_test(NAME loglens_tests COMMAND loglens_tests)

add_test(
  NAME loglens_integration
  COMMAND bash ${CMAKE_CURRENT_SOURCE_DIR}/tests/integration.sh $<TARGET_FILE:loglens>
)
