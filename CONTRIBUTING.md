# Contributing

## Pull request scope

1 PRは1 issueに対応させます。Carbon syntax変更とC++ product変更を同じPRへ混ぜないでください。

## Required checks

```bash
./scripts/verify.sh
make -C product/loglens sanitize
```

Carbonを変更した場合:

```bash
./scripts/run-carbon-smoke.sh
./scripts/run-carbon-katas.sh
```

C ABI (`product/loglens/include/loglens/c_api.h`) またはCarbon interop experimentを変更した場合:

```bash
./scripts/run-c-abi-experiment.sh
```

## Code conventions

- C++ standard: C++23
- code comments: English
- documentation: Japanese or clear simple English
- no owning raw pointers
- expected parse failures are values
- stdout is reserved for machine-readable product output
- new behavior requires tests and updated issue acceptance criteria

## Carbon changes

- pinned nightlyで検証する
- design-only sampleには明示的commentを付ける
- old Explorer interpreter syntaxを持ち込まない
- official docs/release URLと確認日をPRへ記載する
