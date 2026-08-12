#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

# Input validators for the OpenGrep composite action.
#
# Each function returns 0 on success and 1 on failure (never exits) so the
# same code path is exercised by bats unit tests and by action.yml's
# composite steps. Call sites in action.yml convert a nonzero return into
# `exit 1` to abort the step.
#
# Keep error message prefixes stable; the security test suite and downstream
# consumers may match on them.

# Reject path traversal, overlong paths, and ASCII control characters.
validate_path() {
  local path="$1"
  local max_length=500

  # Length check
  if [ ${#path} -gt $max_length ]; then
    printf 'Error: Path too long (max %s chars)\n' "$max_length"
    return 1
  fi

  # Traversal protection: reject any ".." segment or percent-encoded variants
  if [[ "$path" =~ (^|/)\.\.(/|$) ]] \
     || [[ "${path,,}" == *%2e%2e* ]] \
     || [[ "${path,,}" == *..%2f* ]] \
     || [[ "${path,,}" == *%2e.* ]] \
     || [[ "${path,,}" == *.%2e* ]]; then
    printf 'Error: Path traversal detected in: %s\n' "$path"
    return 1
  fi

  # Bash variables cannot contain NUL bytes; reject the other ASCII control
  # bytes under a byte-oriented locale so UTF-8 input is not split with printf.
  local LC_ALL=C
  if [[ "$path" == *[[:cntrl:]]* ]]; then
    printf 'Error: Invalid characters in path: %s\n' "$path"
    return 1
  fi

  return 0
}

# Include pattern validator: length cap, control-char rejection, charset allowlist.
validate_include_pattern() {
  local p="$1"
  local max_length=500

  # Length cap (same defense-in-depth cap as path-like inputs)
  if [ ${#p} -gt $max_length ]; then
    printf 'Error: include pattern too long (>%s chars): %s\n' "$max_length" "$p" >&2
    return 1
  fi

  # Bash variables cannot contain NUL bytes; reject the other ASCII control
  # bytes under a byte-oriented locale.
  local LC_ALL=C
  if [[ "$p" == *[[:cntrl:]]* ]]; then
    printf 'Error: include pattern contains control characters: %s\n' "$p" >&2
    return 1
  fi

  # Whitelist allowed characters (common glob/pattern set)
  # Character class order matters in bash regex: ] must come first to be
  # literal, [ is literal inside a class, - must be last to avoid being a
  # range. Escaping with \] breaks the class entirely (rejects everything).
  if ! [[ "$p" =~ ^[]A-Za-z0-9._*/+?={}:,@%^~[-]+$ ]]; then
    printf 'Error: include pattern has invalid characters: %s\n' "$p" >&2
    return 1
  fi
  return 0
}

# Numeric validator with per-input upper bounds. Empty values are treated
# as "input not provided" and accepted (matches prior behaviour where the
# outer `if [ -n ... ]` gated the check).
validate_numeric() {
  local name="$1"
  local value="$2"

  [ -n "$value" ] || return 0

  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    printf 'Error: %s must be a positive integer\n' "$name"
    return 1
  fi

  case "$name" in
    "max-target-bytes")
      if [ "$value" -gt 1073741824 ]; then  # 1GB limit
        printf 'Error: max-target-bytes too large (max 1GB)\n'
        return 1
      fi
      ;;
    "timeout")
      if [ "$value" -gt 3600 ]; then  # 1 hour limit
        printf 'Error: timeout too large (max 3600 seconds)\n'
        return 1
      fi
      ;;
    "jobs")
      if [ "$value" -gt 16 ]; then  # Reasonable limit
        printf 'Error: jobs too large (max 16)\n'
        return 1
      fi
      ;;
  esac

  return 0
}

# Boolean validator: accept only the literal strings "true" and "false".
# Empty input is accepted (treated as not provided), matching the
# original `if [ -n "$input_value" ]` gating in action.yml.
validate_boolean() {
  local name="$1"
  local value="$2"

  [ -n "$value" ] || return 0

  case "$value" in
    "true"|"false") return 0 ;;
    *)
      printf 'Error: %s must be '\''true'\'' or '\''false'\''\n' "$name"
      return 1
      ;;
  esac
}

# OpenGrep version validator. Accepts "latest" as an explicit opt-in or a
# release tag in the form 1.2.3 / v1.2.3, with optional prerelease suffixes.
validate_opengrep_version() {
  local value="$1"

  [ -n "$value" ] || return 0

  if [ "$value" = "latest" ]; then
    return 0
  fi

  if [[ "$value" =~ ^v?[0-9]+[.][0-9]+[.][0-9]+([-][A-Za-z0-9][A-Za-z0-9.-]*)?$ ]]; then
    return 0
  fi

  printf 'Error: Invalid OpenGrep version\n'
  return 1
}

# Map a runner platform to the OpenGrep release asset to install.
#
# Prints the asset name on stdout and returns 0 for a supported platform;
# prints an explicit error to stderr and returns 1 otherwise. The action
# calls this during input validation so an unsupported runner fails with a
# clear message instead of a curl 404 halfway through the install step.
#
# Adding a platform is one case arm plus the matching checksum wiring:
# upstream publishes opengrep_musllinux_x86, opengrep_manylinux_aarch64,
# opengrep_musllinux_aarch64, opengrep_osx_arm64, opengrep_osx_x86, and
# opengrep_windows_x86.exe alongside the manylinux x86 asset used here.
# Only the manylinux x86 asset is exercised by CI today, so the others stay
# unsupported rather than untested.
#
# Usage: resolve_opengrep_asset <runner-os> <runner-arch>
resolve_opengrep_asset() {
  local runner_os="$1"
  local runner_arch="$2"

  case "${runner_os}/${runner_arch}" in
    "Linux/X64")
      printf 'opengrep_manylinux_x86\n'
      return 0
      ;;
  esac

  printf 'Error: Unsupported runner platform: %s/%s. ' \
    "${runner_os:-unknown}" "${runner_arch:-unknown}" >&2
  printf 'This action supports Linux/X64 runners only.\n' >&2
  return 1
}

# SHA256 validator for user-supplied OpenGrep release checksums.
validate_sha256() {
  local name="$1"
  local value="$2"

  [ -n "$value" ] || return 0

  if [[ "$value" =~ ^[A-Fa-f0-9]{64}$ ]]; then
    return 0
  fi

  printf 'Error: %s must be a 64-character SHA256 checksum\n' "$name"
  return 1
}

# Enum validator. Usage: validate_enum <name> <value> <allowed...>
# Error messages are preserved verbatim for the two call sites in
# action.yml (output-format, severity) and fall back to a generic message
# for any future caller.
validate_enum() {
  local name="$1"
  local value="$2"
  shift 2
  local allowed
  for allowed in "$@"; do
    if [ "$value" = "$allowed" ]; then
      return 0
    fi
  done
  case "$name" in
    "output-format") printf 'Error: Invalid output format\n' ;;
    "severity") printf 'Error: Invalid severity level\n' ;;
    *) printf 'Error: Invalid %s\n' "$name" ;;
  esac
  return 1
}
