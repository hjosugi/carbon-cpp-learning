import Cpp library "loglens/c_api.h";
import Core library "io";

// C ABI interop experiment: calls loglens_bucket_upper from Carbon via
// extern "C" linkage.  Boundary buckets 0 / 1 / 31 / 32 map to
// 0 / 1 / 2^31−1 / UINT32_MAX respectively.
//
// Build:
//   g++ -std=c++23 -Iinclude -O2 -shared -fPIC \
//       src/c_api.cpp src/aggregator.cpp \
//       -o build/c-abi-experiment/libloglens_c_api.so
//   carbon compile \
//       -include-search-root=include \
//       --output=build/c-abi-experiment/c_abi_call.o \
//       carbon_experiments/c_abi_call.carbon
//   carbon link \
//       --output=build/c-abi-experiment/c_abi_call \
//       build/c-abi-experiment/c_abi_call.o \
//       build/c-abi-experiment/libloglens_c_api.so
fn Run() {
  Core.Print(Cpp.loglens_bucket_upper(0));
  Core.Print(Cpp.loglens_bucket_upper(1));
  Core.Print(Cpp.loglens_bucket_upper(31));
  Core.Print(Cpp.loglens_bucket_upper(32));
}
