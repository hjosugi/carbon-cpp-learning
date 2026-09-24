# Carbon nightly refresh

pinned Carbon nightly（`.carbon-version` / `.carbon-sha256`）を新しいnightlyへ更新する手順です。[`carbon-nightly`](../.github/workflows/carbon-nightly.yml) workflowが毎日自動で候補を検証し、通ったものだけをproposalにします。mergeは常に人が行います。

## 自動job

| Job | Step | 失敗した時 |
| --- | --- | --- |
| `discover` | `scripts/carbon-nightly.sh latest`で最新nightlyのversionだけを探す（manual runでは`version` inputで指定） | 何も変わらない |
| `discover` | `scripts/carbon-nightly.sh asset VERSION`でtoolchain archiveの存在・upload完了・download可否を確認し、release asset digestからSHA-256を得る | 何も変わらない |
| `verify` | 候補を`bootstrap-carbon.sh`でinstall（digestと照合）し、`./scripts/check-carbon.sh`でsmoke、kata、pipeline trace、C ABI、C++/Carbon differentialをすべて実行 | proposalを作らない。step summaryに再現commandを出し、logをartifactに残す |
| `propose` | `scripts/carbon-nightly.sh notes CURRENT VERSION`でrelease notesを要約し、mainから作り直した`carbon-nightly/update` branchへ`.carbon-version`、`.carbon-sha256`、READMEのpin行をcommitしてpush | - |
| `propose` | そのbranchのopen pull requestがあれば更新し、なければ作る。作れない場合はissue（`Carbon nightly proposal: <version>`）を作るか更新してcompare linkを残す | - |
| `propose` | `gh workflow run ci.yml --ref carbon-nightly/update`でrequired checksをbranchのcommitに対して実行 | - |

- scheduleは毎日04:41 UTC（Carbon nightlyは02:30 UTC頃に公開）。
- proposal branchは`carbon-nightly/update`の1本だけです。branchがすでに同じversionを現在のmainの上でproposeしていれば何もしません。newer nightlyが出るかmainが進むと、検証後にbranchを作り直してforce pushし、既存のpull request/issueを更新するので、毎日新しいpull requestは増えません。
- 権限は`GITHUB_TOKEN`だけです。`GITHUB_TOKEN`によるpushはworkflowを起動しないため、`propose`は`ci.yml`を`workflow_dispatch`で起動します（`workflow_dispatch`は`GITHUB_TOKEN`からでも起動できる例外です）。
- `GITHUB_TOKEN`でpull requestを作るには、repository設定のActions → General → Workflow permissionsで「Allow GitHub Actions to create and approve pull requests」が必要です。無効な場合、jobは検証済みbranchのcompare linkを持つissueを作り、pull requestは人がそのlinkから作ります（人が作ったpull requestでは通常どおり`ci`が走ります）。
- 失敗したnightlyは`main`の`.carbon-version`に触れないので、current pinは壊れません。

## Proposalのreview

1. `verify` jobのrun linkと、`Carbon labs (pinned nightly)`を含む`ci`の結果を確認する。
2. release notes summaryの「Proposals accepted and merged」と「Toolchain changes that may affect syntax or diagnostics」を読む。完全な一覧はsummary内のFull changelog linkです。
3. toolchain出力を引用しているevidence（`docs/evidence/*.md`の検証日、version、IR/diagnostic抜粋）を必要に応じて取り直す。
4. mergeする。

## Manual run

```bash
gh workflow run carbon-nightly.yml                                            # latest nightly
gh workflow run carbon-nightly.yml -f version=0.0.0-0.nightly.2026.09.24     # specific nightly
```

同じ検証はlocalでも実行できます。

```bash
version="$(./scripts/carbon-nightly.sh latest)"
sha256="$(./scripts/carbon-nightly.sh asset "${version}")"
CARBON_VERSION="${version}" CARBON_SHA256="${sha256}" ./scripts/bootstrap-carbon.sh
CARBON_VERSION="${version}" ./scripts/check-carbon.sh
./scripts/carbon-nightly.sh notes "$(<.carbon-version)" "${version}"
```

`.tools/`にはversionごとのdirectoryでinstallされるので、current pinのtoolchainはそのまま残ります。

## Rollback

mergeしたpinに問題が見つかった場合:

1. bump commitをrevertするpull requestを作る（`git revert <bump commit>`）。`.carbon-version`、`.carbon-sha256`、READMEのpin行が前の値へ戻ります。前のversionとSHA-256はproposalの本文にもあります。
2. `ci`の`Carbon labs (pinned nightly)`が前のpinで通ることを確認してmergeする。
3. localでは`./scripts/bootstrap-carbon.sh`を再実行するだけです。前のversionのtoolchainが`.tools/`に残っていればdownloadもしません。

前のnightlyを`version` inputに指定して`carbon-nightly`を手動実行すると、rollback先も同じ検証を通したproposalとして作れます。
