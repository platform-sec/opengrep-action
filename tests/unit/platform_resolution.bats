#!/usr/bin/env bats
# SPDX-License-Identifier: MIT

# resolve_opengrep_asset coverage.
#
# The action calls this during input validation so an unsupported runner
# fails with an explicit message instead of a curl 404 mid-install. The
# supported platform set is deliberately narrow: only combinations CI
# exercises are accepted, and everything else must be rejected rather than
# guessed at.

# `run --separate-stderr` (used to prove the error never lands on stdout)
# needs bats 1.5.0+; the vendored submodule is 1.11.0.
bats_require_minimum_version 1.5.0

load helpers

# -----------------------------------------------------------------------------
# accepts
# -----------------------------------------------------------------------------

@test "resolve_opengrep_asset: accepts Linux/X64" {
  assert_accepts resolve_opengrep_asset "Linux" "X64"
}

@test "resolve_opengrep_asset: emits the signed CLI asset name for Linux/X64" {
  run resolve_opengrep_asset "Linux" "X64"
  [ "$status" -eq 0 ]
  [ "$output" = "opengrep_manylinux_x86" ]
}

@test "resolve_opengrep_asset: does not emit the unsigned core asset" {
  # Regression guard for the v1 behaviour: installing opengrep-core produced
  # a different result ordering than the CLI every developer runs locally.
  run resolve_opengrep_asset "Linux" "X64"
  [[ "$output" != *"opengrep-core"* ]]
}

# -----------------------------------------------------------------------------
# rejects — unsupported platforms
# -----------------------------------------------------------------------------

@test "resolve_opengrep_asset: rejects macOS/ARM64" {
  assert_rejects resolve_opengrep_asset "macOS" "ARM64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects macOS/X64" {
  assert_rejects resolve_opengrep_asset "macOS" "X64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects Windows/X64" {
  assert_rejects resolve_opengrep_asset "Windows" "X64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects Linux/ARM64" {
  assert_rejects resolve_opengrep_asset "Linux" "ARM64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects Linux/X86 (32-bit)" {
  assert_rejects resolve_opengrep_asset "Linux" "X86" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects Linux/ARM" {
  assert_rejects resolve_opengrep_asset "Linux" "ARM" -- "Unsupported runner platform"
}

# -----------------------------------------------------------------------------
# rejects — missing or malformed platform values
# -----------------------------------------------------------------------------

@test "resolve_opengrep_asset: rejects empty os and arch" {
  assert_rejects resolve_opengrep_asset "" "" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects empty arch with valid os" {
  assert_rejects resolve_opengrep_asset "Linux" "" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects empty os with valid arch" {
  assert_rejects resolve_opengrep_asset "" "X64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: is case sensitive on os" {
  # RUNNER_OS is documented as exactly Linux/Windows/macOS. Matching loosely
  # would accept a value the install step cannot actually serve.
  assert_rejects resolve_opengrep_asset "linux" "X64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: is case sensitive on arch" {
  assert_rejects resolve_opengrep_asset "Linux" "x64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: does not glob-match a wildcard os" {
  assert_rejects resolve_opengrep_asset "*" "X64" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: does not glob-match a wildcard arch" {
  assert_rejects resolve_opengrep_asset "Linux" "*" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: rejects os containing the pair separator" {
  # The case arm matches on "$os/$arch"; a slash in either half must not let
  # a caller forge a supported pair.
  assert_rejects resolve_opengrep_asset "Linux/X64" "" -- "Unsupported runner platform"
}

@test "resolve_opengrep_asset: names the offending platform in the error" {
  run resolve_opengrep_asset "macOS" "ARM64"
  [ "$status" -eq 1 ]
  [[ "$output" == *"macOS/ARM64"* ]]
}

@test "resolve_opengrep_asset: reports unknown for missing values" {
  run resolve_opengrep_asset "" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown/unknown"* ]]
}

@test "resolve_opengrep_asset: error names the supported platform" {
  run resolve_opengrep_asset "Windows" "X64"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Linux/X64"* ]]
}

@test "resolve_opengrep_asset: writes nothing to stdout on rejection" {
  # The install step does ASSET_NAME="$(resolve_opengrep_asset ...)"; leaking
  # the error onto stdout would make it the asset name under `set -e`.
  run --separate-stderr resolve_opengrep_asset "macOS" "ARM64"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
