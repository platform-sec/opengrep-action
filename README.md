# OpenGrep Action

GitHub composite action for running [OpenGrep](https://opengrep.dev) in CI.

The action installs a pinned OpenGrep release, validates all user-controlled
inputs, runs the scan, and exposes JSON/SARIF outputs for downstream workflow
steps.

## Usage

```yaml
name: Security scan

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  opengrep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: scan
        uses: platform-sec/opengrep-action@LATEST_SHA256_HASH
        with:
          target: .
          output-format: json/sarif
          strict: true

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: opengrep-results
          path: |
            ${{ steps.scan.outputs.json-file }}
            ${{ steps.scan.outputs.sarif-file }}
```

## Common Inputs

| Input | Default | Description |
| --- | --- | --- |
| `target` | `.` | File or directory to scan. |
| `patterns` | `auto` | OpenGrep rules, ruleset, or config path. |
| `config` | | OpenGrep configuration file. |
| `output-format` | `json/sarif` | `json/sarif`, `json`, `sarif`, or `text`. |
| `severity` | | Minimum severity: `INFO`, `WARNING`, or `ERROR`. |
| `include` | | Include glob patterns. |
| `exclude` | | Exclude glob patterns. |
| `timeout` | | Per-rule timeout, in seconds. |
| `jobs` | | Number of parallel jobs. |
| `strict` | `true` | Return a non-zero exit code when findings exist. |
| `baseline-commit` | | Git ref or commit hash for differential scans. |
| `opengrep-version` | | OpenGrep version to install. Use an explicit version for reproducibility or `latest` to opt into the newest release at runtime. |
| `opengrep-checksum` | | Optional SHA256 checksum for `opengrep-core_linux_x86.tar.gz`. |

See [`action.yml`](action.yml) for the full input list.

## OpenGrep Versioning

By default, this action installs a reviewed OpenGrep release with a checksum
committed in [`action.yml`](action.yml). That keeps repeated workflow runs
reproducible.

Use an explicit version when you need a newer OpenGrep release:

```yaml
with:
  opengrep-version: '1.19.0'
```

For the strongest override, provide the matching SHA256 checksum from the
OpenGrep release page:

```yaml
with:
  opengrep-version: '1.19.0'
  opengrep-checksum: '4bee4161dbc50c3dfc4a627b3971ac518f39c061513aa398cb81ff5daab6dc4c'
```

If `opengrep-checksum` is omitted for a non-default version, the action
resolves the checksum from OpenGrep release metadata before downloading the
asset. `opengrep-version: latest` is supported as an explicit opt-in and logs a
warning because it is not reproducible across workflow runs.

## Outputs

| Output | Description |
| --- | --- |
| `results-file` | Primary results file. |
| `json-file` | JSON results file, when generated. |
| `sarif-file` | SARIF results file, when generated. |
| `findings-count` | Number of findings reported by OpenGrep. |

## Hardening

This repository treats the action shell boundary as security-sensitive.

- Inputs are passed through `env:` blocks, not interpolated directly into shell
  scripts.
- OpenGrep arguments are built as bash arrays, not command strings.
- Paths, enums, booleans, numeric limits, include patterns, and safe extra
  flags are validated before use.
- The default OpenGrep download is pinned and checksum-verified; explicit
  version overrides are checksum-verified before installation.
- Workflows are linted and validated with `actionlint`, `yamllint`, and
  security-focused checks.
- The test suite includes local GitHub Actions runs through `act`, pytest
  security tests, property-based tests, fuzzing support, and performance
  coverage.

## Development

Install prerequisites for your platform:

```bash
just ubuntu
# or
just macos
```

Useful checks:

```bash
just validate-action
just lint-workflows
just test-basic
just test-security
```

Full local coverage:

```bash
just test-full
```

The main implementation is [`action.yml`](action.yml). Shared validators live in
[`scripts/validators.sh`](scripts/validators.sh), and security tests live in
[`tests/security/`](tests/security/).

## License

MIT. See [`LICENSE`](LICENSE).
