#!/usr/bin/env bats
# SPDX-License-Identifier: MIT

# validate_enum and validate_boolean coverage.
#
# The two enum call sites in action.yml are severity and output-format;
# their error messages are preserved verbatim by scripts/validators.sh
# (security tests and downstream consumers match on them).

load helpers

# -----------------------------------------------------------------------------
# validate_enum — severity
# -----------------------------------------------------------------------------

@test "validate_enum severity: accepts INFO" {
  assert_accepts validate_enum "severity" "INFO" "INFO" "WARNING" "ERROR"
}

@test "validate_enum severity: accepts WARNING" {
  assert_accepts validate_enum "severity" "WARNING" "INFO" "WARNING" "ERROR"
}

@test "validate_enum severity: accepts ERROR" {
  assert_accepts validate_enum "severity" "ERROR" "INFO" "WARNING" "ERROR"
}

@test "validate_enum severity: rejects lowercase 'info'" {
  assert_rejects validate_enum "severity" "info" "INFO" "WARNING" "ERROR" \
    -- "Invalid severity level"
}

@test "validate_enum severity: rejects empty string" {
  assert_rejects validate_enum "severity" "" "INFO" "WARNING" "ERROR" \
    -- "Invalid severity level"
}

@test "validate_enum severity: rejects injection attempt 'INFO; echo'" {
  assert_rejects validate_enum "severity" "INFO; echo" "INFO" "WARNING" "ERROR" \
    -- "Invalid severity level"
}

@test "validate_enum severity: rejects prefix 'INFOO'" {
  assert_rejects validate_enum "severity" "INFOO" "INFO" "WARNING" "ERROR" \
    -- "Invalid severity level"
}

# -----------------------------------------------------------------------------
# validate_enum — output-format
# -----------------------------------------------------------------------------

@test "validate_enum output-format: accepts json" {
  assert_accepts validate_enum "output-format" "json" "json/sarif" "json" "sarif" "text"
}

@test "validate_enum output-format: accepts sarif" {
  assert_accepts validate_enum "output-format" "sarif" "json/sarif" "json" "sarif" "text"
}

@test "validate_enum output-format: accepts text" {
  assert_accepts validate_enum "output-format" "text" "json/sarif" "json" "sarif" "text"
}

@test "validate_enum output-format: accepts 'json/sarif' (dual output)" {
  assert_accepts validate_enum "output-format" "json/sarif" "json/sarif" "json" "sarif" "text"
}

@test "validate_enum output-format: rejects xml" {
  assert_rejects validate_enum "output-format" "xml" "json/sarif" "json" "sarif" "text" \
    -- "Invalid output format"
}

@test "validate_enum output-format: rejects uppercase JSON" {
  assert_rejects validate_enum "output-format" "JSON" "json/sarif" "json" "sarif" "text" \
    -- "Invalid output format"
}

@test "validate_enum output-format: rejects partial match 'jso'" {
  assert_rejects validate_enum "output-format" "jso" "json/sarif" "json" "sarif" "text" \
    -- "Invalid output format"
}

# -----------------------------------------------------------------------------
# validate_enum — generic fallback message
# -----------------------------------------------------------------------------

@test "validate_enum: unknown name uses generic 'Invalid <name>' message" {
  assert_rejects validate_enum "other" "nope" "a" "b" \
    -- "Invalid other"
}

@test "validate_enum: zero allowed values always rejects" {
  assert_rejects validate_enum "other" "x" \
    -- "Invalid other"
}

# -----------------------------------------------------------------------------
# validate_boolean
# -----------------------------------------------------------------------------

@test "validate_boolean: accepts 'true'" {
  assert_accepts validate_boolean "verbose" "true"
}

@test "validate_boolean: accepts 'false'" {
  assert_accepts validate_boolean "verbose" "false"
}

@test "validate_boolean: accepts empty string" {
  # Matches the caller's `if [ -n ... ]` gating behaviour.
  assert_accepts validate_boolean "verbose" ""
}

@test "validate_boolean: rejects uppercase 'TRUE'" {
  assert_rejects validate_boolean "verbose" "TRUE" \
    -- "verbose must be 'true' or 'false'"
}

@test "validate_boolean: rejects '1'" {
  assert_rejects validate_boolean "strict" "1" \
    -- "strict must be 'true' or 'false'"
}

@test "validate_boolean: rejects 'yes'" {
  assert_rejects validate_boolean "strict" "yes" \
    -- "strict must be 'true' or 'false'"
}

@test "validate_boolean: rejects 'true '" {
  # Trailing space must not be accepted — guards against shell trimming bugs.
  assert_rejects validate_boolean "strict" "true " \
    -- "strict must be 'true' or 'false'"
}

@test "validate_boolean: rejects injection attempt 'true; echo'" {
  assert_rejects validate_boolean "verbose" "true; echo" \
    -- "verbose must be 'true' or 'false'"
}
