#!/usr/bin/env bats
# SPDX-License-Identifier: MIT

# validate_path and validate_include_pattern coverage.
# Error messages are pinned verbatim because the security tripwire and
# downstream consumers grep for them.

load helpers

# -----------------------------------------------------------------------------
# validate_path — accepts
# -----------------------------------------------------------------------------

@test "validate_path: accepts '.'" {
  assert_accepts validate_path "."
}

@test "validate_path: accepts plain relative path" {
  assert_accepts validate_path "src/"
}

@test "validate_path: accepts nested relative path with leading ./" {
  assert_accepts validate_path "./foo/bar"
}

@test "validate_path: accepts git remote ref origin/main" {
  assert_accepts validate_path "origin/main"
}

@test "validate_path: accepts git ancestor ref HEAD^" {
  assert_accepts validate_path "HEAD^"
}

@test "validate_path: accepts empty string" {
  # Empty input is gated by the caller (`if [ -n ... ]`), but the function
  # itself must not reject it.
  assert_accepts validate_path ""
}

@test "validate_path: accepts exactly 500-char path" {
  local p
  p=$(printf 'a%.0s' {1..500})
  assert_accepts validate_path "$p"
}

@test "validate_path: accepts /github/ absolute without warning-as-error" {
  # Absolute paths under /github/ are explicitly allowed without warning.
  run validate_path "/github/workspace/x"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Warning:"* ]]
}

@test "validate_path: accepts non-/github/ absolute without warning" {
  run validate_path "/etc/passwd"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Warning:"* ]]
}

# -----------------------------------------------------------------------------
# validate_path — rejects
# -----------------------------------------------------------------------------

@test "validate_path: rejects 501-char path with length message" {
  local p
  p=$(printf 'a%.0s' {1..501})
  assert_rejects validate_path "$p" -- "Path too long (max 500 chars)"
}

@test "validate_path: rejects leading ../" {
  assert_rejects validate_path "../etc" -- "Path traversal detected"
}

@test "validate_path: rejects embedded /../" {
  assert_rejects validate_path "foo/../bar" -- "Path traversal detected"
}

@test "validate_path: rejects trailing /.." {
  assert_rejects validate_path "foo/.." -- "Path traversal detected"
}

@test "validate_path: rejects URL-encoded ..%2f" {
  assert_rejects validate_path "..%2fetc" -- "Path traversal detected"
}

@test "validate_path: rejects URL-encoded %2e%2e" {
  assert_rejects validate_path "%2e%2e/etc" -- "Path traversal detected"
}

@test "validate_path: rejects URL-encoded %2E%2E (case-insensitive)" {
  assert_rejects validate_path "%2E%2E/etc" -- "Path traversal detected"
}

@test "validate_path: rejects mixed ..%2e" {
  assert_rejects validate_path "foo%2e./etc" -- "Path traversal detected"
}

@test "validate_path: rejects mixed .%2e" {
  assert_rejects validate_path "foo.%2e/etc" -- "Path traversal detected"
}

@test "validate_path: rejects newline in path" {
  assert_rejects validate_path $'foo\nbar' -- "Invalid characters in path"
}

@test "validate_path: rejects carriage return in path" {
  assert_rejects validate_path $'foo\rbar' -- "Invalid characters in path"
}

@test "validate_path: plain .. segment name (not traversal) is allowed" {
  # ".." as *part* of a name like "..foo" must NOT match the traversal
  # regex (which requires /../ or start/end anchoring). Pins current
  # behaviour so a future "tighten the check" change is caught.
  assert_accepts validate_path "foo..bar"
}

# -----------------------------------------------------------------------------
# validate_include_pattern — accepts
# -----------------------------------------------------------------------------

@test "validate_include_pattern: accepts *.js" {
  assert_accepts validate_include_pattern "*.js"
}

@test "validate_include_pattern: accepts src/**/*.ts" {
  assert_accepts validate_include_pattern "src/**/*.ts"
}

@test "validate_include_pattern: accepts brace expansion {a,b}.py" {
  assert_accepts validate_include_pattern "{a,b}.py"
}

@test "validate_include_pattern: accepts character class [a-z]*.go" {
  assert_accepts validate_include_pattern "[a-z]*.go"
}

@test "validate_include_pattern: accepts nested brace src/**/*.{js,ts}" {
  assert_accepts validate_include_pattern "src/**/*.{js,ts}"
}

@test "validate_include_pattern: accepts comma list of globs" {
  assert_accepts validate_include_pattern "src/**,config/**,public/**,*.js,*.json"
}

@test "validate_include_pattern: accepts hyphen in filename" {
  assert_accepts validate_include_pattern "foo-bar.py"
}

@test "validate_include_pattern: accepts plus/tilde/at/percent/caret" {
  assert_accepts validate_include_pattern "a+b~c@d%e^f"
}

@test "validate_include_pattern: accepts exactly 500-char glob" {
  local p
  p=$(printf '*%.0s' {1..500})
  assert_accepts validate_include_pattern "$p"
}

# -----------------------------------------------------------------------------
# validate_include_pattern — rejects
# -----------------------------------------------------------------------------

@test "validate_include_pattern: rejects 501-char with length message" {
  local p
  p=$(printf '*%.0s' {1..501})
  assert_rejects validate_include_pattern "$p" -- "too long (>500 chars)"
}

@test "validate_include_pattern: rejects semicolon (;echo)" {
  assert_rejects validate_include_pattern ";echo" -- "invalid characters"
}

@test "validate_include_pattern: rejects backtick" {
  # shellcheck disable=SC2016
  assert_rejects validate_include_pattern '`id`' -- "invalid characters"
}

@test "validate_include_pattern: rejects command substitution \$(x)" {
  # shellcheck disable=SC2016
  assert_rejects validate_include_pattern '$(x)' -- "invalid characters"
}

@test "validate_include_pattern: rejects space" {
  assert_rejects validate_include_pattern "a b" -- "invalid characters"
}

@test "validate_include_pattern: rejects pipe" {
  assert_rejects validate_include_pattern "a|b" -- "invalid characters"
}

@test "validate_include_pattern: rejects redirect >" {
  assert_rejects validate_include_pattern "a>b" -- "invalid characters"
}

@test "validate_include_pattern: rejects redirect <" {
  assert_rejects validate_include_pattern "a<b" -- "invalid characters"
}

@test "validate_include_pattern: rejects ampersand" {
  assert_rejects validate_include_pattern "a&b" -- "invalid characters"
}

@test "validate_include_pattern: rejects newline (control char branch)" {
  assert_rejects validate_include_pattern $'a\nb' -- "control characters"
}

@test "validate_include_pattern: rejects CR (control char branch)" {
  assert_rejects validate_include_pattern $'a\rb' -- "control characters"
}

@test "validate_include_pattern: rejects double quote" {
  assert_rejects validate_include_pattern 'a"b' -- "invalid characters"
}

@test "validate_include_pattern: rejects single quote" {
  assert_rejects validate_include_pattern "a'b" -- "invalid characters"
}

@test "validate_include_pattern: rejects backslash" {
  assert_rejects validate_include_pattern 'a\b' -- "invalid characters"
}
