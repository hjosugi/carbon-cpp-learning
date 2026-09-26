# Carbon × Modern C++ 実践ラボ

2026-07-12時点の公式Carbon設計・nightly toolchainを基準に、Carbonの言語設計を学びながら、同じ題材をC++23で製品品質まで仕上げるハンズオンです。

## 最初に知るべきこと

Carbonはまだ`0.1`未到達の実験的言語です。公式nightlyは動きますが、構文・標準ライブラリ・CLIは変更されます。Carbon部分は評価・学習用であり、本番利用を保証しません。

この教材では役割を分けます。

| 領域 | 目的 | 実行保証 |
| --- | --- | --- |
| `hands-on/carbon/nightly-smoke` | 現在のtoolchainを実際にcompile/link/runする | pinned nightlyを基準 |
| `hands-on/carbon/design-labs` | classes、generics、choice、package設計を学ぶ | design-first。一部は未実装の可能性あり |
| `hands-on/cpp` | Carbonの狙いをC++23と比較する | GCC 13+/Clang 17+ |
| `product/loglens` | ストリーミングログ集計CLIを製品品質で実装する | C++23版v1.3.0をテスト済み |
| `issues` | 学習から製品化までの作業をGitHub Issues化する | そのまま転記可能 |

## 5分で開始

Ubuntu 24.04またはWSL2を推奨します。Carbon nightlyの配布対象は限定されています。

```bash
cd carbon-cpp-learning
./scripts/bootstrap-carbon.sh
./scripts/run-carbon-smoke.sh
./scripts/verify.sh
```

C++製品だけ先に動かす場合:

```bash
cd product/loglens
make test
make release
./build/release/loglens --input samples/access.log
```

## 学習順

1. [現在地と制約](docs/00-status.md)
2. [環境構築](docs/01-setup.md)
3. [Carbon構文ハンズオン](docs/02-carbon-hands-on.md)
4. [Carbonの設計思想](docs/03-carbon-design.md)
5. [Modern C++23比較](docs/04-modern-cpp23.md)
6. [C++相互運用](docs/05-interop.md)
7. [LogLensアーキテクチャ](docs/06-product-design.md)
8. [8週間プラン](docs/07-study-plan.md)
9. [公式リソース](docs/08-resources.md)
10. [Toolchain設計](docs/09-toolchain-design.md)
11. [検証結果](docs/10-verification.md)
12. [Product readiness review](docs/11-readiness-review.md)
13. [Report schema contract](docs/12-report-schema.md)
14. [Carbon nightly refresh](docs/13-carbon-nightly-refresh.md)
15. [Issuesバックログ](issues/README.md)

## 完了条件

- Carbonの`compile`→`link`→実行を自力で説明できる。
- `let`/`var`、tuple、class、interface、checked generics、`choice`をC++と比較できる。
- CarbonがC++を置換する完成言語ではなく、段階移行を狙う実験であると説明できる。
- LogLensのparser、aggregator、bounded-memory percentile、CLI、testを変更できる。
- RFC 3339 validation、入力/resource limits、schema versionを説明できる。
- sanitizer、fuzzing、benchmark、SBOM、CI、release buildを含む品質判断ができる。

## 基準日と更新方針

- 調査基準日: 2026-07-12
- pinned Carbon nightly: `0.0.0-0.nightly.2026.09.26`
- `carbon-nightly` workflowが新しいnightlyを毎日検証し、通ったものだけをpin更新proposalにする（[手順とrollback](docs/13-carbon-nightly-refresh.md)）。

## ライセンス

教材固有コードはMIT。参照先のCarbonプロジェクトはApache-2.0 with LLVM Exceptionsです。
