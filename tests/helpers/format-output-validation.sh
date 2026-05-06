#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

FORMAT_RULE_ID="format-eval"
FORMAT_RULE_MESSAGE="eval detected for format validation"
FORMAT_SOURCE_SNIPPET="eval(userInput);"

create_format_fixture() {
  local root="${1:-test-code/format-validation}"
  local severity="${2:-ERROR}"

  mkdir -p "$root/src"
  cat > "$root/src/eval.js" <<EOF
$FORMAT_SOURCE_SNIPPET
EOF
  cat > "$root/rules.yml" <<EOF
rules:
  - id: $FORMAT_RULE_ID
    pattern: eval(\$EXPR)
    message: $FORMAT_RULE_MESSAGE
    languages: [javascript]
    severity: $severity
EOF

  if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1; then
    local attempts=0
    until git -C "$root" add .; do
      attempts=$((attempts + 1))
      if [ "$attempts" -ge 20 ]; then
        echo "Unable to stage format fixture after $attempts attempts"
        exit 1
      fi
      sleep 1
    done
  fi
}

assert_file_exists() {
  local file="$1"
  local label="${2:-output}"

  [ -f "$file" ] || {
    echo "$label missing: $file"
    exit 1
  }
}

assert_nonempty_file() {
  local file="$1"
  local label="${2:-output}"

  assert_file_exists "$file" "$label"
  [ -s "$file" ] || {
    echo "$label empty: $file"
    exit 1
  }
}

assert_valid_json_file() {
  local file="$1"
  assert_nonempty_file "$file" "JSON output"
  jq empty "$file" >/dev/null
}

assert_valid_sarif_file() {
  local file="$1"
  assert_nonempty_file "$file" "SARIF output"
  jq empty "$file" >/dev/null
}

assert_format_json_finding() {
  local file="$1"

  assert_valid_json_file "$file"
  jq -e --arg rule_id "$FORMAT_RULE_ID" --arg message "$FORMAT_RULE_MESSAGE" '
    .results | length == 1 and
    (.[0].check_id == $rule_id or (.[0].check_id | endswith("." + $rule_id))) and
    .[0].extra.message == $message
  ' "$file" >/dev/null
}

assert_format_sarif_finding() {
  local file="$1"

  assert_valid_sarif_file "$file"
  jq -e --arg rule_id "$FORMAT_RULE_ID" --arg message "$FORMAT_RULE_MESSAGE" '
    [.runs[].results[]?] | length == 1 and
    (.[0].ruleId == $rule_id or (.[0].ruleId | endswith("." + $rule_id))) and
    .[0].message.text == $message
  ' "$file" >/dev/null
}

assert_format_text_finding() {
  local file="$1"
  local normalized_file

  assert_nonempty_file "$file" "Text output"
  normalized_file=$(mktemp)
  sed -E $'s/\x1B\\[[0-9;]*[[:alpha:]]//g' "$file" > "$normalized_file"
  if ! grep -F "$FORMAT_RULE_ID" "$normalized_file" >/dev/null ||
    ! grep -F "$FORMAT_RULE_MESSAGE" "$normalized_file" >/dev/null ||
    ! grep -F "$FORMAT_SOURCE_SNIPPET" "$normalized_file" >/dev/null; then
    rm -f "$normalized_file"
    return 1
  fi
  rm -f "$normalized_file"
}

assert_format_output() {
  local format="$1"
  local file="$2"

  case "$format" in
    json) assert_format_json_finding "$file" ;;
    sarif) assert_format_sarif_finding "$file" ;;
    text) assert_format_text_finding "$file" ;;
    *)
      echo "Unsupported format assertion: $format"
      exit 1
      ;;
  esac
}
