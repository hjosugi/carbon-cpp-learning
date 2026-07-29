# Benchmark and soak test evidence

## Machine specification

CIではubuntu-24.04 (GitHub Actions standard runner: 4 vCPU / ~16 GB RAM / Linux x86_64)。

ローカルで再現する手順:

```bash
g++ --version  # GCC 14 on Ubuntu 24.04
make -C product/loglens bench-matrix
```

## Compiler flags

```
-O3 -DNDEBUG -std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow
```

`product/loglens/Makefile` の `release` target を参照。

## Generator

`bench/generate.cpp` は固定xorshift seed (`0x9e3779b97f4a7c15`) で行を生成します。
同じ引数で常に同一出力を生成し、テストの決定性を保ちます。

```bash
# 1M lines, 1K services (先頭3行を確認)
./product/loglens/build/benchmark/generate 1000000 1000 | head -3
```

## Benchmark matrix (1M lines)

`make -C product/loglens bench-matrix` または
`bash product/loglens/bench/bench_matrix.sh 1000000` で実行。

CIの `resource` job が毎PR実行し、raw `/usr/bin/time -v` レポートと
`.summary` ファイルを `loglens-resource-evidence` artifactに保存します。

| lines     | services | throughput (lines/s) | peak RSS      |
|-----------|----------|----------------------|---------------|
| 1,000,000 | 1        | CI artifact          | CI artifact   |
| 1,000,000 | 1,000    | CI artifact          | CI artifact   |
| 1,000,000 | 100,000  | CI artifact          | CI artifact   |

## Regression thresholds

`bench/check_regression.sh` がCI `resource` jobで実行し、
閾値違反時にexitcode 1でジョブを失敗させます。

閾値はO(services × 344 B)の期待working setの約10倍に設定しています
(344 B = `sizeof(ServiceStats)` on GCC/x86-64、
`docs/evidence/histogram-analysis.md` 参照)。

| lines     | services | RSS limit   | elapsed limit |
|-----------|----------|-------------|---------------|
| 1,000,000 | 1        | 20,000 kB   | 60 s          |
| 1,000,000 | 1,000    | 80,000 kB   | 60 s          |
| 1,000,000 | 100,000  | 500,000 kB  | 180 s         |

## Soak test (100M lines)

毎週月曜 3:23 UTC または手動で `.github/workflows/soak.yml` が実行されます。
raw reportは `loglens-soak-<run_id>` artifactに14日間保存されます。

ローカル手動実行:

```bash
bash product/loglens/bench/resource_report.sh 100000000 1
bash product/loglens/bench/resource_report.sh 100000000 1000
bash product/loglens/bench/resource_report.sh 100000000 100000
```

## Profile / flamegraph

Linux `perf` によるhot path profile手順 (フレームポインタ付きビルド必須):

```bash
# フレームポインタ付きrelease buildを作成
make -C product/loglens EXTRA_CXXFLAGS="-fno-omit-frame-pointer" release

# プロファイル記録
product/loglens/build/benchmark/generate 1000000 1000 | \
  perf record -g --call-graph fp \
  product/loglens/build/release/loglens --input - >/dev/null

# flamegraph生成 (https://github.com/brendangregg/FlameGraph が必要)
perf script | stackcollapse-perf.pl | flamegraph.pl \
  > product/loglens/build/benchmark/flamegraph-1000000-1000.svg
```

flamegraph SVGの保存先規則:
`product/loglens/build/benchmark/flamegraph-<lines>-<services>.svg`
(`build/` はgitignoreされているため、成果物はArtifactとして別途保存してください)
