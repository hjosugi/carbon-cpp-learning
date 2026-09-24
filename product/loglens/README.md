# LogLens

External dependencyなしのC++23 streaming log analytics CLIです。Carbon migration experimentのproduction baselineでもあります。

## Build and run

```bash
make test release
./build/release/loglens --input samples/access.log
```

strict mode:

```bash
./build/release/loglens --input samples/access.log --strict
echo $?
```

## Input

1行5 field、space-separatedです。

```text
timestamp level service latency_ms status
```

- `timestamp`: RFC 3339 UTC subset `YYYY-MM-DDTHH:MM:SS[.fraction]Z`
- `level`: `TRACE|DEBUG|INFO|WARN|ERROR|FATAL`
- `service`: 最大128文字、ASCII alphanumeric/`_`/`-`/`.`
- `latency_ms`: unsigned 32-bit integer
- `status`: `100..599`

## Output semantics

- `schema_version`: 現在は`1`
- `accepted`: valid lines
- `malformed`: rejected lines
- `error_rate`: 4xx + 5xx / service count
- `latency_avg_ms`: arithmetic mean
- `latency_max_ms`: exact maximum
- `latency_p95_upper_ms`: p95を含むpower-of-two bucketの上限
- `latency_sum_saturated`: 64-bit sumがsaturateしたか

`latency_p95_upper_ms`はexact percentileではありません。memoryを入力行数に対してboundedにするための近似です。

## Quality commands

```bash
make warnings
make test
make sanitize
make CXX=clang++ fuzz
make CXX=clang++ FUZZ_SECONDS=600 fuzz-long
make benchmark
make resource-report
make bench-matrix check-regression
make LINES=100000000 bench-matrix check-regression
make release
```

LeakSanitizerを利用できる環境:

```bash
ASAN_DETECT_LEAKS=1 make sanitize
```

ptrace制約のあるsandboxではleak detectionを0にし、ASan/UBSanのみを実行します。

週次`fuzz-long` workflowは10分実行し、拡張corpus、crash候補、SHA-256一覧を14日間artifactとして保持します。crash inputは最小化・review後に`tests/corpus/`へ追加します。

## Resource limits

```bash
cat samples/access.log | ./build/release/loglens --input - \
  --max-line-bytes 1048576 --max-services 10000
```

oversized lineまたはservice cardinality上限超過はexit `5`でfail closedします。
duplicate optionはexit `2`です。`--version`はrelease versionを表示します。

fail closedを選ぶ理由は、`other` serviceへ自動集約するとtenant/service identityが失われ、攻撃や設定誤りを正常trafficとして隠すためです。limit eventはstderrとexit `5`でobservableです。output先のdisk fullまたはclosed pipeはstderrとexit `3`になります。

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | success |
| 2 | invalid CLI arguments |
| 3 | input/output error |
| 4 | malformed record in strict mode |
| 5 | resource limit or allocation failure |

## Known limits

- native Windows binaryはこのbaselineのrelease対象外です。
- Carbon componentはexperimentalで、C++ executableの必須dependencyではありません。

## Binary archive install

```bash
tar -xzf loglens-1.3.0-linux-x86_64.tar.gz
sudo install -m 0755 loglens-1.3.0-linux-x86_64/bin/loglens /usr/local/bin/loglens
loglens --version
```

uninstallは`sudo rm /usr/local/bin/loglens`です。archive同梱の`PROVENANCE.txt`と、Release添付のSPDX SBOM／`SHA256SUMS`を確認できます。
