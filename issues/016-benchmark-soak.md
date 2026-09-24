# benchmarkとsoak testを作る

Labels: `area/product`, `type/test`, `priority/p1`

Depends on: #011, #014

## Tasks

- [ ] deterministic 1M/100M line generatorを作る
- [ ] throughput、CPU、peak RSSを測る
- [ ] 1/1K/100K unique servicesで比較する
- [ ] regression thresholdを決める

## Acceptance criteria

machine specとcommandを含む再現可能benchmark reportがあり、hot pathがprofileで説明される。

## Evidence

raw results、compiler flags、profile flamegraph pathを保存する。
