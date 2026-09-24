# Histogram correctness and memory evidence

検証日: 2026-07-12

## Bucket boundaries

`LatencyHistogram`は`std::bit_width(latency_ms)`をindexとする33 bucketsです。

| Bucket | Inclusive input range | Reported upper |
| --- | --- | --- |
| 0 | 0 | 0 |
| 1 | 1 | 1 |
| 2 | 2..3 | 3 |
| n (`2..31`) | `2^(n-1)..2^n-1` | `2^n-1` |
| 32 | `2^31..UINT32_MAX` | `UINT32_MAX` |

unit testは全33 bucketsのlower/upper valueを投入し、single-value percentileとC ABI `loglens_bucket_upper`が同じupperを返すことを確認します。

## Exact percentile comparison

nearest-rank exact percentileと同じ20 valuesで比較します。

| Quantile | Exact | Histogram upper | Upper / exact |
| --- | ---: | ---: | ---: |
| p50 | 31 | 31 | 1.000 |
| p95 | 512 | 1023 | 1.998 |
| p99 | 1000 | 1023 | 1.023 |

positive valueのbucket upperは常にexact value以上かつ`2 × exact`未満です。0のupperは0です。したがってfield名を`latency_p95_upper_ms`とし、exact percentileと誤認させません。

## Overflow

`ServiceStats::add_latency`を64-bit max直前のstateからtestし、overflow時にsumを`UINT64_MAX`へsaturateして`latency_sum_saturated=true`にすることを確認します。

## Memory complexity

GCC 16.1.1 / Linux x86_64でのlayout evidence:

| Type | `sizeof` |
| --- | ---: |
| `LatencyHistogram` | 272 bytes |
| `ServiceStats` | 344 bytes |

各serviceは固定33 bucketsと固定counterだけを保持します。入力record自体は保持しないため、aggregation stateは`O(unique services × 33)`、入力行数に対して`O(1)`です。`unordered_map`のnode/bucket/string overheadはstandard library実装とservice名長に依存します。

peak RSSはCIの`Resource and benchmark evidence` jobで1,000,000 records、1 / 1,000 / 100,000 servicesを測り（結果とregression thresholdは[benchmark report](benchmark-report.md)）、raw `/usr/bin/time -v` reportをartifactとして保存します。同じartifactには行長・service cardinality・`/dev/full`・closed pipeの異常系integration suiteのpeak RSSも含みます。
