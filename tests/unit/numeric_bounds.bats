#!/usr/bin/env bats
# SPDX-License-Identifier: MIT

# validate_numeric coverage. Bounds per scripts/validators.sh:
#   max-target-bytes: 0..1073741824 (1 GB)
#   timeout:          0..3600       (1 hour)
#   jobs:             0..16

load helpers

# -----------------------------------------------------------------------------
# Empty input is always accepted (caller gates with `if [ -n ... ]`)
# -----------------------------------------------------------------------------

@test "validate_numeric: empty max-target-bytes accepted" {
  assert_accepts validate_numeric "max-target-bytes" ""
}

@test "validate_numeric: empty timeout accepted" {
  assert_accepts validate_numeric "timeout" ""
}

@test "validate_numeric: empty jobs accepted" {
  assert_accepts validate_numeric "jobs" ""
}

# -----------------------------------------------------------------------------
# Non-integer / non-positive-integer forms rejected with the same message
# -----------------------------------------------------------------------------

@test "validate_numeric: rejects non-numeric string" {
  assert_rejects validate_numeric "timeout" "abc" -- "timeout must be a positive integer"
}

@test "validate_numeric: rejects float 1.5" {
  assert_rejects validate_numeric "timeout" "1.5" -- "positive integer"
}

@test "validate_numeric: rejects scientific notation" {
  assert_rejects validate_numeric "timeout" "1e5" -- "positive integer"
}

@test "validate_numeric: rejects hex 0x10" {
  assert_rejects validate_numeric "jobs" "0x10" -- "positive integer"
}

@test "validate_numeric: rejects negative -1" {
  assert_rejects validate_numeric "timeout" "-1" -- "positive integer"
}

@test "validate_numeric: rejects leading plus" {
  assert_rejects validate_numeric "timeout" "+1" -- "positive integer"
}

@test "validate_numeric: rejects whitespace-padded" {
  assert_rejects validate_numeric "timeout" " 10 " -- "positive integer"
}

@test "validate_numeric: rejects trailing newline" {
  assert_rejects validate_numeric "timeout" $'10\n' -- "positive integer"
}

# -----------------------------------------------------------------------------
# max-target-bytes bounds (0..1073741824)
# -----------------------------------------------------------------------------

@test "validate_numeric max-target-bytes: accepts 0" {
  assert_accepts validate_numeric "max-target-bytes" "0"
}

@test "validate_numeric max-target-bytes: accepts leading-zero 0000" {
  # `[0-9]+` allows it; pin the behaviour.
  assert_accepts validate_numeric "max-target-bytes" "0000"
}

@test "validate_numeric max-target-bytes: accepts exactly 1GB" {
  assert_accepts validate_numeric "max-target-bytes" "1073741824"
}

@test "validate_numeric max-target-bytes: rejects 1GB+1" {
  assert_rejects validate_numeric "max-target-bytes" "1073741825" \
    -- "max-target-bytes too large (max 1GB)"
}

@test "validate_numeric max-target-bytes: rejects huge value" {
  assert_rejects validate_numeric "max-target-bytes" "9999999999" \
    -- "max-target-bytes too large"
}

# -----------------------------------------------------------------------------
# timeout bounds (0..3600)
# -----------------------------------------------------------------------------

@test "validate_numeric timeout: accepts 0" {
  assert_accepts validate_numeric "timeout" "0"
}

@test "validate_numeric timeout: accepts 3600" {
  assert_accepts validate_numeric "timeout" "3600"
}

@test "validate_numeric timeout: rejects 3601" {
  assert_rejects validate_numeric "timeout" "3601" \
    -- "timeout too large (max 3600 seconds)"
}

@test "validate_numeric timeout: rejects 99999" {
  assert_rejects validate_numeric "timeout" "99999" -- "timeout too large"
}

# -----------------------------------------------------------------------------
# jobs bounds (0..16)
# -----------------------------------------------------------------------------

@test "validate_numeric jobs: accepts 0" {
  assert_accepts validate_numeric "jobs" "0"
}

@test "validate_numeric jobs: accepts 1" {
  assert_accepts validate_numeric "jobs" "1"
}

@test "validate_numeric jobs: accepts 16" {
  assert_accepts validate_numeric "jobs" "16"
}

@test "validate_numeric jobs: rejects 17" {
  assert_rejects validate_numeric "jobs" "17" -- "jobs too large (max 16)"
}

@test "validate_numeric jobs: rejects 100" {
  assert_rejects validate_numeric "jobs" "100" -- "jobs too large"
}

# -----------------------------------------------------------------------------
# Unknown names fall through the case — no upper-bound check
# -----------------------------------------------------------------------------

@test "validate_numeric: unknown name skips bound check (format still enforced)" {
  assert_accepts validate_numeric "other" "99999999"
  assert_rejects validate_numeric "other" "abc" -- "positive integer"
}
