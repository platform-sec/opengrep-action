# OpenGrep Action

GitHub composite action for running [OpenGrep](https://opengrep.dev) in CI.

The action installs a pinned OpenGrep release, validates all user-controlled
inputs, runs the scan, and exposes JSON/SARIF outputs for downstream workflow
steps.

## Pinning

Pin this action to a full commit SHA, never to a tag or branch. List every
released tag with the SHA it points at, newest first, and copy the line you
want:

```bash
gh api repos/platform-sec/opengrep-action/tags \
  --jq '.[] | "uses: platform-sec/opengrep-action@\(.commit.sha)  # \(.name)"'
```

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
        # Placeholder — see "Pinning" above for the command that prints the real SHA
        uses: platform-sec/opengrep-action@<REPLACE-WITH-COMMIT-SHA>
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
| `opengrep-version` | `1.27.1` | OpenGrep version to install. Use an explicit version for reproducibility or `latest` to opt into the newest release at runtime. |
| `opengrep-checksum` | | Optional SHA256 checksum for the `opengrep_manylinux_x86` asset. |
| `verify-signature` | `true` | Verify the Sigstore signature on the OpenGrep release asset. |

See [`action.yml`](action.yml) for the full input list.

## Requirements

This action supports **Linux x64 runners only** (`ubuntu-latest` and friends).
Any other `RUNNER_OS`/`RUNNER_ARCH` combination fails during input validation
with an explicit message rather than a download error. Upstream publishes musl,
arm64, macOS, and Windows assets, so other platforms can be added; they are
unsupported here because CI does not exercise them.

## OpenGrep Versioning

By default, this action installs a reviewed OpenGrep release with a checksum
committed in [`action.yml`](action.yml). That keeps repeated workflow runs
reproducible.

Use an explicit version to pin a different OpenGrep release:

```yaml
with:
  opengrep-version: '1.27.1'
```

For the strongest override, provide the matching SHA256 checksum of that
release's `opengrep_manylinux_x86` asset:

```yaml
with:
  opengrep-version: '1.27.1'
  opengrep-checksum: '58053da76672bbeb5b0a5441021c58338707052e10f81d777140ca879bd491ce'
```

If `opengrep-checksum` is omitted for a non-default version, the action
resolves the checksum from OpenGrep release metadata before downloading the
asset. `opengrep-version: latest` is supported as an explicit opt-in and logs a
warning because it is not reproducible across workflow runs.

The pinned default is kept current by
[`update-opengrep.yml`](.github/workflows/update-opengrep.yml), which opens a
reviewable PR when upstream publishes a release. When the pin trails upstream
at scan time, the action logs a one-line notice; set `disable-version-check` to
suppress it.

## Signature Verification

The action installs the `opengrep_manylinux_x86` CLI asset, which upstream
signs with Sigstore. By default the action installs `cosign` and verifies the
signature against a pinned identity before installing the binary:

```text
identity: https://github.com/opengrep/opengrep/.github/workflows/rolling-release.yml@refs/heads/main
issuer:   https://token.actions.githubusercontent.com
```

This is a provenance check — it proves the binary came from OpenGrep's own
release workflow, which a checksum cannot establish. The pinned SHA256 is kept
as a separate integrity gate, because it is reviewed at commit time and so
resists a mutated upstream release.

Verification needs egress to GitHub releases and the Sigstore transparency log.
On a runner that cannot reach them, disable it explicitly:

```yaml
with:
  verify-signature: false
```

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
- The downloaded asset's Sigstore signature is verified against a pinned
  signing identity before the binary is installed.
- Structured scan output is asserted to be present and well-formed before the
  action reports success, so a truncated report cannot be read as "no
  findings" downstream.
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
