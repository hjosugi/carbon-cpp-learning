# Benchmark and soak report

検証日: 2026-09-24

## Machines

| | CI benchmark | Local soak / profile |
| --- | --- | --- |
| Runner / host | GitHub-hosted `ubuntu-24.04` | developer laptop |
| CPU | AMD EPYC 7763, 4 vCPU (2 cores × 2 threads) | AMD Ryzen 3 7330U, 8 threads |
| Memory | 16,373,452 kB | 23,434,660 kB |
| OS / kernel | Ubuntu 24.04.5 LTS / Linux 6.17.0-1022-azure | CachyOS / Linux 7.2.6 |
| Compiler | g++ 13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04.1) | g++ 16.2.1 |

CIの値は`bench/machine_spec.sh`がjobごとに`resource-machine.txt`へ記録します。local machineは測定中にほかのbuildで高負荷（load average 60〜98）だったため、localのwall-clockとthroughputは参考値です。peak RSSとprofileの比率は負荷の影響を受けにくい指標として使います。

Compiler flags（release build、`product/loglens/Makefile`）:

```text
-std=c++23 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -O3 -DNDEBUG
```

## Commands

```bash
make -C product/loglens bench-matrix                 # 1M lines x 1 / 1,000 / 100,000 services
make -C product/loglens check-regression             # thresholds below
make -C product/loglens LINES=100000000 bench-matrix # 100M-line soak
make -C product/loglens LINES=100000000 check-regression
bash product/loglens/bench/profile.sh 1000000 1000   # perf profile + flamegraph
```

各measurementは次の形です。GNU timeは`loglens`だけを包むので、CPU timeとpeak RSSはgeneratorを含みません。`--max-services`はcardinalityに合わせます（default 10,000では100,000-service caseがexit 5でfail closedするため）。

```bash
build/benchmark/generate LINES SERVICES |
  /usr/bin/time -v build/release/loglens --input - --max-services SERVICES >/dev/null
```

`bench/generate.cpp`は固定xorshift seed（`0x9e3779b97f4a7c15`）で、同じ引数なら常に同じ入力を出します。`throughput_lines_per_sec`はlines / wall-clock elapsedです。

## Results: 1M lines (CI)

Raw report: [`Resource and benchmark evidence` job](https://github.com/hjosugi/carbon-cpp-learning/actions/runs/36009717414/job/107666971267)（artifact `loglens-resource-evidence`に`resource-1000000-*.txt`、`.summary`、`resource-machine.txt`）。

| Services | User s | System s | CPU | Elapsed | Peak RSS | Throughput |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1.30 | 0.03 | 100% | 1.33 s | 3,832 kB | 751,880 lines/s |
| 1,000 | 1.43 | 0.04 | 100% | 1.48 s | 4,376 kB | 675,676 lines/s |
| 100,000 | 1.58 | 0.06 | 100% | 1.64 s | 87,796 kB | 609,756 lines/s |

- CPU 100%なので、pipeのbottleneckはgeneratorではなくloglensです。
- 1→1,000 servicesのRSS増加は約0.5 MB、1,000→100,000は約83 MB（約0.85 kB/service）。`ServiceStats`（344 bytes）にservice名、`unordered_map` node、bucket arrayが加わった値で、[histogram analysis](histogram-analysis.md)の`O(unique services × 33)`と一致します。

## Soak: 100M lines (local)

| Services | User s | System s | CPU | Elapsed | Peak RSS | Throughput |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 137.82 | 4.88 | 80% | 2:57.59 | 4,324 kB | 563,095 lines/s |
| 1,000 | 167.30 | 5.28 | 82% | 3:30.09 | 4,904 kB | 475,986 lines/s |
| 100,000 | 201.34 | 5.92 | 84% | 4:04.69 | 88,932 kB | 408,680 lines/s |

入力を100倍にしてもpeak RSSは1M lines時とほぼ同じです（同じlocal machineの1M×100,000は88,472 kB、100M×100,000は88,932 kB）。aggregation stateは入力行数に対して`O(1)`で、100M行でもleakやgrowthはありません。`check_regression.sh 100000000`はこの3件をすべてOKと判定しました。

CIでは`.github/workflows/soak.yml`が毎週月曜03:23 UTCと手動実行で同じ100M×{1, 1,000, 100,000}を測り、同じthresholdで判定し、raw reportを`loglens-soak-<run_id>` artifactに14日間保存します。

## Regression thresholds

`bench/check_regression.sh [lines]`がCI `resource` jobで毎PR実行され、1つでも超えるとjobを失敗させます。

| Services | Peak RSS limit | CPU limit (user + system) | Exit |
| ---: | ---: | ---: | --- |
| 1 | 8,000 kB | 7 s / 1M lines | must be 0 |
| 1,000 | 9,000 kB | 7 s / 1M lines | must be 0 |
| 100,000 | 180,000 kB | 8 s / 1M lines | must be 0 |

- RSS limitは上表CI値の約2倍で、行数に依存しません。100M-line soakも同じlimitで判定するため、`O(lines)`のmemory growthは確実に検出されます。
- CPU limitはCI値の約5倍で、行数に比例します。wall-clockではなくloglensのCPU timeを使うので、generator待ちやrunnerの混雑では失敗しにくく、1 recordあたりの処理が数倍遅くなるregressionは検出します。
- unit/integration testsはwall clockに合否を依存させません（[test matrix](test-matrix.md)）。時間を使う判定はこのbenchmark gateだけです。

## Profile: hot path

`bench/profile.sh`でrelease flagsに`-g -fno-omit-frame-pointer`を加えたbinaryを別pathにbuildし、file入力（generatorを除外）を`perf record --call-graph dwarf`で測りました（local machine、g++ 16.2.1）。

Flamegraph:

- [`flamegraph-1M-1K.svg`](flamegraph-1M-1K.svg)（1M lines × 1,000 services）
- [`flamegraph-1M-100K.svg`](flamegraph-1M-100K.svg)（1M lines × 100,000 services）

`profile.sh`は`product/loglens/build/benchmark/flamegraph-<lines>-<services>.svg`へ出力します。

Self time上位（`perf report --no-children --sort symbol`）:

| Symbol | 1,000 services | 100,000 services |
| --- | ---: | ---: |
| `std::istream::get()` | 35.4% | 18.6% |
| `std::istream::sentry::sentry` | 23.7% | 12.5% |
| `loglens::Aggregator::add` | 16.0% | 33.6% |
| `loglens::parse_line` | 13.6% | 6.7% |
| `loglens::read_bounded_line` | 6.9% | 3.4% |
| `loglens::render_json` | - | 6.2% |
| `std::_Hash_bytes` | 1.5% | 1.0% |

同じcommandを繰り返しても比率の差は数ポイント以内でした。

hot pathの説明:

1. **入力読み込み（1,000 servicesで約66%）**: `read_bounded_line`は`std::istream::get()`で1文字ずつ読みます。1文字ごとに`sentry`の構築（stream stateとtieの確認）が走り、これが`get()`本体と合わせて時間の約6割を占めます。line長の上限を守るための設計ですが、throughputの上限はここで決まります。
2. **service lookup（100,000 servicesで約36%）**: `Aggregator::add`の`unordered_map::find`です。serviceが100,000種類になるとhash tableのnodeが増え、1 recordあたりのlookupが重くなります。service名は短いのでSSOに収まり、`std::string`生成のheap allocationはprofileに現れません。
3. **parse（約7〜14%）**: `parse_line`のfield分割、RFC 3339 timestamp、整数の検証です。
4. **JSON出力**: 100,000 servicesではservice名のsortを含む`render_json`が約6%になります。1回だけなので行数には比例しません。

改善候補（この変更では未実施）: bufferへまとめて読んでから改行を探す、`unordered_map`のtransparent hashでlookupを軽くする。いずれもline-size limitとfail-closed動作を保つことが前提です。
