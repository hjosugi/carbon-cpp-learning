# Changelog

## 1.1.0 - 2026-09-24

- Added a LogLens benchmark matrix (1M lines x 1 / 1,000 / 100,000 services) with CPU and peak-RSS regression thresholds in CI, a weekly 100M-line soak workflow, a perf profile script, and a benchmark report with flamegraphs.
- Added the Carbon C ABI experiment: a pinned-nightly Carbon executable calls `loglens_bucket_upper` through a shared library, with symbol, lowered-signature, and 0/1/31/32 boundary checks.
- Added checked Carbon basic syntax kata solutions with expected output and expected check-phase diagnostics.
- Added a Carbon toolchain pipeline trace from tokens to object file, with lex/parse/check diagnostic owner checks.
- Replaced committed graphify skill files with `scripts/graphify.sh` setup and update entry points.

## 1.0.0 - 2026-07-12

- Added strict RFC 3339 UTC timestamp validation and CRLF-safe bounded input.
- Added stdin, version output, stable duplicate-option policy, schema version 1, and exit-code integration tests.
- Added line-size and unique-service limits with fail-closed behavior.
- Added GCC/Clang checks, ASan/UBSan, a libFuzzer target, and a deterministic benchmark generator.
- Added reproducible Linux x86_64 packaging, checksums, provenance, and SPDX 2.3 SBOM.
- Verified the pinned Carbon nightly archive digest and Carbon compile/link/run labs.

## 0.1.0 - 2026-07-12

- Added Carbon nightly bootstrap and four smoke labs.
- Added Carbon design labs for structs, choice, generics, and C++ imports.
- Added Carbon language, safety, interop, package, and toolchain design guides.
- Added production-oriented C++23 LogLens CLI.
- Added bounded-memory histogram, explicit parse errors, tests, sanitizers, and CI.
- Added 27 implementation and learning issues with acceptance criteria and evidence.
