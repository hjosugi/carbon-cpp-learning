# benchmarkとsoak testを作る

Labels: `area/product`, `type/test`, `priority/p1`

Depends on: #011, #014

## Tasks

- [x] deterministic 1M/100M line generatorを作る
- [x] throughput、CPU、peak RSSを測る
- [x] 1/1K/100K unique servicesで比較する
- [x] regression thresholdを決める

## Acceptance criteria

machine specとcommandを含む再現可能benchmark reportがあり、hot pathがprofileで説明される。

## Evidence

raw results、compiler flags、profile flamegraph pathを保存する。
