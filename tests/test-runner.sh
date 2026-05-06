#!/bin/bash
# SPDX-License-Identifier: MIT

# test-runner.sh - Integration test runner for OpenGrep GitHub Action
# Focuses on functional and integration testing using GitHub Actions workflows
# Security testing is handled by pytest in tests/security/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ACT_VERSION="v0.2.69"
DOCKER_IMAGE="catthehacker/ubuntu:act-22.04"
TEST_TIMEOUT=300  # 5 minutes (reduced from 10)

echo -e "${BLUE}🧪 OpenGrep GitHub Action Integration Test Runner${NC}"
echo "=================================================="

# Function to print colored output
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if act is installed
    if ! command -v act &> /dev/null; then
        log_warning "Act is not installed. Installing act..."
        install_act
    else
        log_success "Act is already installed: $(act --version)"
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq and try again."
        log_info "Install with: sudo apt-get install jq  # Ubuntu/Debian"
        log_info "Install with: brew install jq         # macOS"
        exit 1
    fi
    
    # Check if required files exist
    if [ ! -f "action.yml" ]; then
        log_error "action.yml not found. Please run this script from the repository root."
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Function to install act
install_act() {
    log_info "Installing act $ACT_VERSION..."
    
    case "$(uname -s)" in
        Linux*)
            PLATFORM="Linux"
            ;;
        Darwin*)
            PLATFORM="Darwin"
            ;;
        *)
            log_error "Unsupported platform: $(uname -s)"
            exit 1
            ;;
    esac
    
    case "$(uname -m)" in
        x86_64)
            ARCH="x86_64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
    
    DOWNLOAD_URL="https://github.com/nektos/act/releases/download/$ACT_VERSION/act_${PLATFORM}_${ARCH}.tar.gz"
    
    # Download and install
    curl -L "$DOWNLOAD_URL" | tar -xz
    sudo mv act /usr/local/bin/act
    chmod +x /usr/local/bin/act
    
    log_success "Act $ACT_VERSION installed successfully"
}

# Function to setup test environment
setup_test_environment() {
    log_info "Setting up integration test environment..."
    
    # Create test directories
    mkdir -p tests/data
    mkdir -p tests/results
    
    # Create .actrc if it doesn't exist
    if [ ! -f ".actrc" ]; then
        log_info "Creating .actrc configuration..."
        cat > .actrc << EOF
-P ubuntu-latest=$DOCKER_IMAGE
--env GITHUB_TOKEN=fake_token_for_testing
--env RUNNER_DEBUG=1
--bind
--use-gitignore=false
EOF
    fi
    
    # Create minimal test data (security tests are handled by pytest)
    create_basic_test_data
    
    # Pull Docker image
    log_info "Pulling Docker image: $DOCKER_IMAGE"
    docker pull "$DOCKER_IMAGE"
    
    log_success "Integration test environment setup completed"
}

# Function to create basic test data for integration tests
create_basic_test_data() {
    log_info "Creating basic test data for integration tests..."
    
    # Basic vulnerable files for functional testing
    mkdir -p tests/data/python
    cat > tests/data/python/basic_test.py << 'EOF'
import os

# Simple test case for basic functionality
def test_function(user_input):
    command = f"ls {user_input}"
    os.system(command)  # This should be detected
EOF

    # Basic JavaScript test file
    mkdir -p tests/data/javascript
    cat > tests/data/javascript/basic_test.js << 'EOF'
// Simple test case for format validation
function testFunction(userInput) {
    eval(userInput); // This should be detected
}
EOF

    # Clean test files (should not trigger findings)
    mkdir -p tests/data/clean
    cat > tests/data/clean/safe.py << 'EOF'
import hashlib

def safe_function():
    return hashlib.sha256(b"test").hexdigest()
EOF

    # Basic OpenGrep rules for testing
    mkdir -p tests/data/rules
    cat > tests/data/rules/basic-rules.yml << 'EOF'
rules:
  - id: test-eval
    pattern: eval($EXPR)
    message: "eval() detected"
    languages: [javascript]
    severity: ERROR
    
  - id: test-os-system
    pattern: os.system($CMD)
    message: "os.system() detected"
    languages: [python]
    severity: ERROR
EOF

    log_success "Basic test data created for integration tests"
}

# Function to prepare an act-compatible workflow file. Some security-focused
# third-party actions now require Node runtimes newer than the local act
# runner supports, so local tests strip those steps while keeping the checked-in
# workflow unchanged for GitHub-hosted CI.
prepare_act_workflow() {
    local source_workflow=".github/workflows/test-opengrep-action.yml"
    local temp_workflow

    temp_workflow=$(mktemp "${TMPDIR:-/tmp}/opengrep-act-workflow.XXXXXX.yml")
    awk '
        /^      - name: Harden Runner$/ { skip = 3; next }
        skip > 0 { skip--; next }
        { print }
    ' "$source_workflow" > "$temp_workflow"

    printf '%s\n' "$temp_workflow"
}

copy_action_under_test() {
    local destination=$1

    mkdir -p "$destination"
    tar \
        --exclude=.git \
        --exclude=.venv \
        --exclude=.pytest_cache \
        --exclude=opengrep-results \
        --exclude=tests/results \
        -cf - . | (cd "$destination" && tar -xf -)
}

run_baseline_commit_test() {
    local workspace
    local rc

    workspace=$(mktemp -d "${TMPDIR:-/tmp}/opengrep-baseline-fixture.XXXXXX")
    trap 'chmod -R u+w "$workspace" >/dev/null 2>&1 || true; rm -rf "$workspace" >/dev/null 2>&1 || true' RETURN

    log_info "Creating isolated baseline fixture repo..."
    mkdir -p "$workspace/fixture-src"
    copy_action_under_test "$workspace/action-under-test"

    cat > "$workspace/.actrc" << EOF
-P ubuntu-latest=$DOCKER_IMAGE
--env GITHUB_TOKEN=fake_token_for_testing
--bind
--use-gitignore=false
EOF

    cat > "$workspace/fixture-src/vulnerable.py" <<'EOF'
import os

def unsafe_command(user_input):
    os.system(f"ls {user_input}")
EOF

    mkdir -p "$workspace/.github/workflows"
    cat > "$workspace/.github/workflows/baseline-commit.yml" <<'EOF'
---
name: Baseline Commit

on:
  push:

jobs:
  baseline-commit:
    runs-on: ubuntu-latest
    steps:
      - name: Capture Baseline Commit
        id: repo
        shell: bash
        run: |
          set -euo pipefail
                    git init
                    git checkout -B main
                    git config user.name 'Test Runner'
                    git config user.email 'test@example.com'

                    git add action-under-test fixture-src
                    git commit -m 'test: baseline fixture'

                    baseline_commit=$(git rev-parse HEAD)
          printf 'baseline_commit=%s\n' "$baseline_commit" >> "$GITHUB_OUTPUT"

                    printf 'baseline smoke\n' > fixture-src/baseline-smoke.txt
                    git add fixture-src/baseline-smoke.txt
                    git commit -m 'test: add baseline smoke file'

      - name: Run Baseline Scan
        id: scan
        uses: ./action-under-test
        with:
          target: 'fixture-src/'
          output-format: 'json'
          baseline-commit: ${{ steps.repo.outputs.baseline_commit }}
          strict: 'false'

      - name: Verify Baseline Results
        shell: bash
        run: |
          set -euo pipefail
          FILE="${{ steps.scan.outputs.json-file }}"
          [ -f "$FILE" ] || { echo 'JSON missing'; exit 1; }
          [ "${{ steps.scan.outputs.findings-count }}" = "0" ] || {
            echo 'Expected no new findings against baseline'
            exit 1
          }
          jq -e '.results | length == 0' "$FILE" >/dev/null
EOF

    log_info "Running baseline-commit integration test against fixture repo..."
    (
        cd "$workspace"
        timeout $TEST_TIMEOUT act -W .github/workflows/baseline-commit.yml -j baseline-commit -P ubuntu-latest="$DOCKER_IMAGE" --env ACT=true --verbose
    )
    rc=$?
    if [ $rc -eq 0 ]; then
        log_success "Test 'test-baseline-commit' passed"
        return 0
    fi

    if [ $rc -eq 124 ]; then
        log_error "Test 'test-baseline-commit' timed out after ${TEST_TIMEOUT}s"
    else
        log_error "Test 'test-baseline-commit' failed with exit code $rc"
    fi
    return $rc
}

# Function to run a specific test
run_test() {
    local test_name=$1
    local workflow_file
    local exit_code

    if [ "$test_name" = "test-baseline-commit" ]; then
        log_info "Running test: $test_name"
        run_baseline_commit_test
        return $?
    fi

    workflow_file=$(prepare_act_workflow)
    
    log_info "Running test: $test_name"
    
    # Run act with timeout
    if timeout $TEST_TIMEOUT act -W "$workflow_file" -j "$test_name" --env ACT=true --verbose; then
        log_success "Test '$test_name' passed"
        rm -f "$workflow_file"
        return 0
    else
        exit_code=$?
        rm -f "$workflow_file"
        if [ $exit_code -eq 124 ]; then
            log_error "Test '$test_name' timed out after ${TEST_TIMEOUT}s"
        else
            log_error "Test '$test_name' failed with exit code $exit_code"
        fi
        return $exit_code
    fi
}

# Function to run all integration tests
run_all_tests() {
    log_info "Running integration tests..."
    
    # Core integration tests (focused on GitHub Actions functionality)
    local tests=(
        "test-basic-scan"
        "test-single-formats"
        "test-strict-mode"
        "test-advanced-options"
        "test-baseline-commit"
        "test-error-handling"
    )
    
    local passed=0
    local failed=0
    local failed_tests=()

    for test in "${tests[@]}"; do
        log_info "Starting integration test job: $test"
        run_test "$test"
        local rc=$?
        if [ $rc -eq 0 ]; then
            ((++passed))
        else
            ((++failed))
            failed_tests+=("$test")
            log_warning "Recorded failure for $test (exit code $rc)"
        fi
        echo
    done
    
    # Print summary
    echo "=================================================="
    log_info "Integration Test Summary:"
    log_success "$passed tests passed"
    
    if [ $failed -gt 0 ]; then
        log_error "$failed tests failed:"
        for test in "${failed_tests[@]}"; do
            echo "  - $test"
        done
        return 1
    else
        log_success "All integration tests passed! 🎉"
        log_info "Note: Security tests are run separately via pytest"
        return 0
    fi
}

# Function to run performance tests (simplified)
run_performance_tests() {
    log_info "Running basic performance tests..."
    
    # Create simple performance test dataset
    mkdir -p tests/data/performance
    
    # Generate a moderate number of test files
    for i in {1..20}; do
        echo "print('test file $i')" > "tests/data/performance/file$i.py"
    done
    
    # Generate one moderately large file
    python3 -c "
for i in range(1000):
    print(f'def function_{i}():')
    print('    user_input = input()')
    if i % 100 == 0:  # Add occasional vulnerability
        print(f'    os.system(user_input)  # Test line {i}')
    else:
        print('    print(user_input)')
    print()
" > tests/data/performance/large_file.py
    
    log_info "Performance test data created (20 files, ~1k lines)"
    
    # Run a basic performance test
        local start_time
        start_time=$(date +%s)
    if run_test "test-basic-scan"; then
            local end_time
            end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "Performance test completed in ${duration}s"
    else
        log_error "Performance test failed"
        return 1
    fi
}

# Function to clean up test artifacts
cleanup() {
    log_info "Cleaning up test artifacts..."
    
    # Remove test data
    rm -rf tests/data
    rm -rf tests/results
    
    # Clean up any leftover containers
    docker container prune -f > /dev/null 2>&1 || true
    
    log_success "Cleanup completed"
}

# Main function
main() {
    case "${1:-all}" in
        "check"|"prerequisites")
            check_prerequisites
            ;;
        "setup")
            check_prerequisites
            setup_test_environment
            ;;
        "test")
            if [ -n "$2" ]; then
                check_prerequisites
                setup_test_environment
                run_test "$2"
            else
                check_prerequisites
                setup_test_environment
                run_all_tests
                local exit_code=$?
                cleanup
                exit $exit_code
            fi
            ;;
        "performance"|"perf")
            check_prerequisites
            setup_test_environment
            run_performance_tests
            ;;
        "security"|"sec")
            log_info "Running security tripwire via pytest..."
            if [ -d "tests/security" ]; then
                local venv="tests/security/.venv"
                if [ ! -d "$venv" ]; then
                    log_error "Security venv not found — run 'just test-security' to create it"
                    exit 1
                fi
                # shellcheck disable=SC1091
                . "$venv/bin/activate"
                python3 -m pytest tests/security "${@:2}"
                exit $?
            else
                log_error "Security tests directory not found"
                exit 1
            fi
            ;;
        "full"|"comprehensive")
            log_info "Running comprehensive test suite..."
            check_prerequisites
            setup_test_environment
            
            # Run integration tests
            if run_all_tests; then
                log_success "Integration tests passed"
            else
                log_error "Integration tests failed"
                exit 1
            fi
            
            # Run security tripwire
            log_info "Running security tripwire..."
            if [ -d "tests/security/.venv" ]; then
                # shellcheck disable=SC1091
                . tests/security/.venv/bin/activate
                if python3 -m pytest tests/security; then
                    log_success "Security tripwire passed"
                else
                    log_error "Security tripwire failed"
                    exit 1
                fi
            else
                log_warning "Security venv missing — run 'just test-security' first"
            fi
            
            log_success "All tests passed! 🎉"
            ;;
        "clean"|"cleanup")
            cleanup
            ;;
        "all"|"")
            check_prerequisites
            setup_test_environment
            run_all_tests
            local exit_code=$?
            cleanup
            exit $exit_code
            ;;
        "help"|"--help"|"-h")
            echo "Usage: $0 [command] [test-name]"
            echo ""
            echo "Commands:"
            echo "  check         Check prerequisites only"
            echo "  setup         Setup integration test environment"
            echo "  test [name]   Run specific test or all integration tests"
            echo "  security      Run action-boundary tripwire via pytest"
            echo "  performance   Run performance tests"
            echo "  full          Run both integration and security tests"
            echo "  clean         Clean up test artifacts"
            echo "  all           Run integration tests only (default)"
            echo "  help          Show this help"
            echo ""
            echo "Integration test names:"
            echo "  test-basic-scan       Test basic scanning functionality"
            echo "  test-single-formats   Test output format validation"
            echo "  test-strict-mode      Test strict mode behavior"
            echo "  test-advanced-options Test advanced configuration options"
            echo "  test-baseline-commit  Test differential baseline scanning"
            echo "  test-error-handling   Test error handling and validation"
            echo ""
            echo "Note: Security testing is handled by pytest in tests/security/"
            echo "Use '$0 security' to run security tests or '$0 full' for everything"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo; log_warning "Test runner interrupted"; cleanup; exit 130' INT

# Run main function
main "$@"
