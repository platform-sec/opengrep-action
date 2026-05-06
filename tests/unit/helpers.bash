# SPDX-License-Identifier: MIT

# Common helpers for bats unit tests. Sourced by every *.bats file.
#
# The validators under test use `return 1` (never `exit`) so `run` can
# capture the status without killing the test. See scripts/validators.sh
# for the contract.

# shellcheck shell=bash
# shellcheck disable=SC1091  # sourced path is dynamic at bats test time
source "${BATS_TEST_DIRNAME}/../../scripts/validators.sh"

# `status` and `output` are populated by bats-core's `run` function.
# shellcheck disable=SC2154

# assert_rejects <fn> <arg...> [-- <reason substring>]
# Runs <fn> with <arg...> and asserts non-zero exit. If the optional
# `-- <substring>` is present, also asserts the captured stdout+stderr
# contains it. Use this to pin error messages that downstream consumers
# or the security test suite match on.
assert_rejects() {
  local fn="$1"
  shift
  local args=()
  local reason=""
  while [ $# -gt 0 ]; do
    if [ "$1" = "--" ]; then
      shift
      reason="$1"
      shift
      continue
    fi
    args+=("$1")
    shift
  done
  run "$fn" "${args[@]}"
  if [ "$status" -eq 0 ]; then
    printf 'expected rejection from %s but got status 0\noutput: %s\n' \
      "$fn" "$output" >&2
    return 1
  fi
  if [ -n "$reason" ] && [[ "$output" != *"$reason"* ]]; then
    printf 'expected output to contain %q\ngot: %s\n' "$reason" "$output" >&2
    return 1
  fi
}

# assert_accepts <fn> <arg...>
# Runs <fn> with <arg...> and asserts zero exit. Warnings on stderr are
# tolerated (validate_path emits one for absolute paths outside /github/).
assert_accepts() {
  local fn="$1"
  shift
  run "$fn" "$@"
  if [ "$status" -ne 0 ]; then
    printf 'expected acceptance from %s but got status %d\noutput: %s\n' \
      "$fn" "$status" "$output" >&2
    return 1
  fi
}
