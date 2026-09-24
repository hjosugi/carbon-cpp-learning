# LogLens test matrix

| Layer | Coverage | Command |
| --- | --- | --- |
| parser table | valid RFC 3339, every stable error code, integer boundaries | `make test` |
| histogram boundaries | all 33 buckets, lower/upper values, C ABI equality | `make test` |
| histogram properties | nearest-rank p50/p95/p99 upper/error bound | `make test` |
| aggregation | counters, ordering, repeated render, sum saturation | `make test` |
| input/resource | CRLF, bounded line drain, service cardinality | `make test` |
| CLI golden | zero/one/many services, valid JSON, byte equality | `make integration` |
| CLI failure | exit 2/3/4/5, `/dev/full`, closed pipe | `make integration` |
| adversarial RSS | line/service limits, `/dev/full`, closed pipe | CI `Resource and benchmark evidence` |
| benchmark regression | 1M lines x 1 / 1,000 / 100,000 services, peak RSS and CPU limits | `make bench-matrix check-regression` |
| soak | 100M lines x 1 / 1,000 / 100,000 services, same RSS limits | weekly `soak` workflow |
| build modes | debug and release run the same integration suite | `make integration` |
| memory/UB | ASan, LSan where available, UBSan | `make sanitize` |
| parser fuzz | valid/invalid/oversized seeds, 10,000-case PR smoke | `make CXX=clang++ fuzz` |
| long fuzz | 10 minutes, corpus hashes/artifact retention | `make CXX=clang++ fuzz-long` |

10分実測値とcorpus hashは[`fuzz-10min.md`](fuzz-10min.md)に保存しています。

testsはnetwork、wall clock、random seedへ合否を依存させません（CPU timeを使うのはbenchmark regression gateだけで、baselineの約5倍の余裕を持たせています）。benchmark generatorは固定xorshift stateを使います。golden testは同じmany-service inputを2回実行し、byte-identical outputを確認します。
