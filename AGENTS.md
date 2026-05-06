# AGENTS.md

Guidance for coding agents working in this repository.

## Repository Purpose

This repository ships a single GitHub composite Action that installs and runs
[OpenGrep](https://opengrep.dev) for static security scanning. There is no
library or binary source. The product logic lives in `action.yml` as a sequence
of `shell: bash` composite steps. Supporting files such as the justfile, tests,
and scripts exist to validate that action.

## Architecture

### Primary Artifact

`action.yml` is the product. Its composite `runs.steps` are, in order:

1. Validate Inputs - path traversal, length, charset, null-byte, enum, and
   numeric bounds checks.
2. Security Environment Setup - sets umask, disables core dumps, clears risky
   environment variables, and constrains `PATH`.
3. Install OpenGrep - pinned download with checksum verification.
4. Configure - builds the `OPENGREP_ARGS` bash array, resolves output paths by
   format, and writes args to `$OUTPUT_DIR/opengrep-args.txt`.
5. Run OpenGrep Scan - reads args back with `mapfile`, executes `opengrep`,
   emits `findings-count` through `jq`, and honors `strict` mode.
6. Report Results - prints the summary and sets the `results-ready` flag.

### Security-Sensitive Patterns

Preserve these patterns when editing `action.yml`:

- User inputs are passed through `env:` blocks with the `INPUTS_*` prefix.
  Never inline `${{ inputs.* }}` inside a shell `run:` block.
- Scanner arguments are assembled as a bash array with
  `OPENGREP_ARGS+=(...)` and expanded as `"${OPENGREP_ARGS[@]}"`. Do not
  collapse the args into a string.
- Reuse the canonical validators:
  - `validate_path` for path traversal, URL-encoded `..`, and control
    character checks.
  - `validate_include_pattern` for charset allowlisting and length caps.

## Tests

Tests are split into two independent layers, both driven by `just`.

### Unit Tests

`tests/unit/` contains Bats coverage for the shared shell validators in
`scripts/validators.sh`. Run it with `just test-unit`.

### Integration Tests

`tests/test-runner.sh` runs `.github/workflows/test-opengrep-action.yml`
locally through `act` using the pinned `catthehacker/ubuntu:act-22.04` image
and `act v0.2.69`.

Named jobs include:

- `test-basic-scan`
- `test-single-formats`
- `test-advanced-options`
- `test-strict-mode`
- `test-baseline-commit`
- `test-error-handling`
- `performance`

Sample fixtures live in `test-code/`.

### Security Tests

`tests/security/` contains the pytest and Hypothesis security test suite. Its
virtual environment lives at `tests/security/.venv` and is created by the
`_security-venv` recipe. These tests validate input-handling behavior in the
action, not OpenGrep itself.

Unit tests should stay limited to shared shell helpers. Expected action
coverage still comes from integration and security tests.

## Common Commands

Use `just` for day-to-day tasks. See `justfile` for the full list.

```bash
just dev-setup           # one-time setup: act, Docker image, dirs
just check               # verify Docker, act, jq, action.yml
just status              # detailed environment report

just test-basic          # fastest smoke test via act
just test-unit           # validator unit tests via Bats
just test                # full integration matrix
just test-fast           # test-basic + test-security-quick
just test-security       # pytest suite in tests/security/
just test-full           # integration + security + performance + benchmark
just test-changed        # choose suite based on git diff HEAD~1
just debug               # RUNNER_DEBUG=1 re-run of test-basic-scan

just lint                # workflow lint, action validation, security validation
just lint-workflows      # actionlint, local binary or Docker fallback
just lint-zizmor         # zizmor workflow security audit
just validate-action     # yamllint + required-field check on action.yml

just clean               # remove test artifacts
just clean-all           # remove artifacts, venv, caches, Docker images
```

Run a single integration job with:

```bash
tests/test-runner.sh test <job-id>
```

Example:

```bash
tests/test-runner.sh test test-basic-scan
```

Run a single security pytest with:

```bash
cd tests/security
. .venv/bin/activate
pytest path/to/test_file.py::test_name
```

Prerequisites are Docker, `act`, `jq`, and `python3`. Install dependencies on
Ubuntu with `just ubuntu` and on macOS with `just macos`.

## Workflows

`.github/workflows/` contains CI, integration, security scan, local act test,
pre-release, and release workflows. Release notes are generated from
conventional commits by `pre-release.yml` and `release.yml`.

## Release

`scripts/release.sh` backs the `just release-*` recipes. Version bumps are
driven by conventional commits:

- `feat:` -> minor
- `fix:` -> patch
- `feat!:` or `BREAKING CHANGE:` -> major

Major-version floating tags such as `v1` and `v2` are force-pushed on release.
See `RELEASE.md` for details.

## Editing Rules

- Treat `action.yml` as the primary artifact.
- After any `action.yml` change, run at least:

  ```bash
  just validate-action
  just lint-workflows
  just test-basic
  ```

- For input-validation changes, also run:

  ```bash
  just test-security
  ```

- Preserve the injection-safe patterns described above.
- Use conventional commit prefixes recognized by the release tooling:
  `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `security:`, `perf:`, and
  `ci:`.
