# SPDX-License-Identifier: MIT

# OpenGrep GitHub Action — task runner
# Run `just` or `just --list` to see available recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false

docker_image := "catthehacker/ubuntu:act-22.04"
act_version  := "v0.2.69"
test_timeout := "300"
zizmor_version := "1.24.1"

project_root := justfile_directory()
tests_dir    := project_root / "tests"
unit_dir     := tests_dir / "unit"
bats_bin     := unit_dir / "bats" / "bin" / "bats"
security_dir := tests_dir / "security"
results_dir  := tests_dir / "results"
scripts_dir  := project_root / "scripts"

default:
    @just --list

# Check prerequisites (Docker, act, jq, action files)
check:
    @echo "🔄 Checking prerequisites..."
    @docker info >/dev/null 2>&1 || { echo "❌ Docker is not running"; exit 1; }
    @echo "✅ Docker is running"
    @if command -v act >/dev/null 2>&1; then \
        echo "✅ Act: $(act --version)"; \
    else \
        echo "⚠️  Act is not installed. Run 'just install-act'"; \
    fi
    @command -v jq >/dev/null 2>&1 || { echo "❌ jq is not installed"; exit 1; }
    @echo "✅ jq is available"
    @[ -f action.yml ] || { echo "❌ action.yml not found"; exit 1; }
    @echo "✅ action.yml found"
    @[ -f .github/workflows/test-opengrep-action.yml ] || { echo "❌ Test workflow not found"; exit 1; }
    @echo "✅ Test workflow found"

# Install act for local GitHub Actions testing
install-act:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v act >/dev/null 2>&1; then
        echo "✅ Act already installed: $(act --version)"
        exit 0
    fi
    echo "🔄 Downloading act {{act_version}}..."
    curl -s https://api.github.com/repos/nektos/act/releases/latest \
        | grep "browser_download_url.*Linux_x86_64.tar.gz" \
        | cut -d : -f 2,3 | tr -d \" | xargs curl -L | tar -xz
    sudo mv act /usr/local/bin/
    echo "✅ Act installed: $(act --version)"

# Setup test environment
setup: check
    @echo "🔄 Setting up test environment..."
    @mkdir -p "{{results_dir}}" "{{security_dir}}/results"
    @echo "🔄 Pulling Docker image {{docker_image}}..."
    @docker pull {{docker_image}} >/dev/null 2>&1 || { echo "❌ Failed to pull Docker image"; exit 1; }
    @"{{tests_dir}}/test-runner.sh" setup
    @echo "✅ Test environment ready"

# --- Core test categories ------------------------------------------------

# Run validator unit tests (bats-core, no Docker required)
test-unit:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -x "{{bats_bin}}" ]; then
        echo "❌ bats submodule missing. Run: git submodule update --init --recursive"
        exit 1
    fi
    "{{bats_bin}}" "{{unit_dir}}"

# Run basic functionality tests
test-basic: setup
    @echo "🔄 Running basic tests..."
    @timeout {{test_timeout}} "{{tests_dir}}/test-runner.sh" test test-basic-scan
    @echo "✅ Basic tests completed"

# Run format validation tests
test-formats: setup
    @echo "🔄 Running format tests..."
    @timeout {{test_timeout}} "{{tests_dir}}/test-runner.sh" test test-single-formats
    @echo "✅ Format tests completed"

# Run advanced options tests
test-advanced: setup
    @echo "🔄 Running advanced tests..."
    @timeout {{test_timeout}} "{{tests_dir}}/test-runner.sh" test test-advanced-options
    @echo "✅ Advanced tests completed"

# Run error handling tests
test-errors: setup
    @echo "🔄 Running error handling tests..."
    @timeout {{test_timeout}} "{{tests_dir}}/test-runner.sh" test test-error-handling
    @echo "✅ Error handling tests completed"

# Run performance tests
test-performance: setup
    @echo "🔄 Running performance tests..."
    @timeout {{test_timeout}} "{{tests_dir}}/test-runner.sh" performance
    @echo "✅ Performance tests completed"

# Run basic test suite in parallel
test-parallel: setup
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Running tests in parallel..."
    pids=()
    for recipe in test-basic test-formats test-advanced test-errors; do
        just "$recipe" &
        pids+=($!)
    done
    rc=0
    for pid in "${pids[@]}"; do
        wait "$pid" || rc=$?
    done
    [ $rc -eq 0 ] && echo "✅ Parallel tests completed" || { echo "❌ Parallel tests failed"; exit $rc; }

# Run GitHub Actions integration tests
test-integration: setup
    @echo "🔄 Running integration tests..."
    @timeout {{test_timeout}} "{{tests_dir}}/test-runner.sh" test
    @echo "✅ Integration tests completed"

# Alias for test-integration
test: test-integration

# --- Security testing (pytest) -------------------------------------------

_security-venv:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f "{{security_dir}}/requirements.txt" ] || { echo "❌ Security requirements.txt not found"; exit 1; }
    cd "{{security_dir}}"
    [ -d .venv ] || python3 -m venv .venv
    . .venv/bin/activate
    pip install -q -r requirements.txt

# Run action-boundary tripwire (real act runs, ~75s)
test-security: _security-venv
    @echo "🔄 Running action-boundary tripwire..."
    @"{{tests_dir}}/test-runner.sh" security
    @echo "✅ Tripwire completed"

# --- Combined suites -----------------------------------------------------

# Run integration and security tests
test-all: test-integration test-security
    @echo "✅ All tests completed"

# Run fast tests (unit + one integration smoke)
test-fast:
    @echo "🔄 Running fast test suite..."
    @just test-unit
    @just test-basic
    @echo "✅ Fast tests completed"

# Run full test suite (parallel + security + performance)
test-full:
    @echo "🔄 Running full test suite..."
    @just test-parallel
    @just test-security
    @just test-performance
    @echo "✅ Full test suite completed"

# Run tests based on changed files (git diff HEAD~1)
test-changed:
    #!/usr/bin/env bash
    set -euo pipefail
    changed=$(git diff --name-only HEAD~1 2>/dev/null || echo "")
    if echo "$changed" | grep -q "action.yml\|scripts/\|tests/"; then
        echo "ℹ️  Core files changed — running full suite"
        just test-all
    elif echo "$changed" | grep -q '\.py$'; then
        echo "ℹ️  Python files changed — running security tests"
        just test-security
    elif echo "$changed" | grep -q 'justfile\|\.yml$'; then
        echo "ℹ️  Config files changed — running basic tests"
        just test-basic
    else
        echo "ℹ️  No significant changes — running fast suite"
        just test-fast
    fi

# --- CI targets ----------------------------------------------------------

# Run tests in CI mode
test-ci:
    @echo "🔄 Running CI tests..."
    @"{{tests_dir}}/test-runner.sh" test
    @echo "✅ CI tests completed"

# Run security tripwire in CI mode
test-ci-security: _security-venv
    @echo "🔄 Running CI security tripwire..."
    @"{{tests_dir}}/test-runner.sh" security
    @echo "✅ CI security tripwire completed"

# Run tests optimized for GitHub Actions
test-github-actions:
    @echo "🔄 Running GitHub Actions optimized tests..."
    @GITHUB_ACTIONS=true RUNNER_DEBUG=1 just test-parallel
    @echo "✅ GitHub Actions tests completed"

# --- Debugging -----------------------------------------------------------

# Run tests in debug mode
debug: setup
    @echo "🔄 Running tests in debug mode..."
    @RUNNER_DEBUG=1 "{{tests_dir}}/test-runner.sh" test test-basic-scan
    @echo "ℹ️  Debug logs available in test.log"

# Run tests with maximum verbosity
debug-verbose: setup
    @echo "🔄 Running tests with maximum verbosity..."
    @RUNNER_DEBUG=1 RUNNER_VERBOSE=1 "{{tests_dir}}/test-runner.sh" test test-basic-scan 2>&1 | tee debug.log
    @echo "✅ Verbose debug completed — check debug.log"

# Show recent test logs
logs:
    #!/usr/bin/env bash
    for f in test.log "{{tests_dir}}/test.log" debug.log; do
        if [ -f "$f" ]; then
            echo "ℹ️  Last 50 lines of $f:"
            tail -50 "$f"
            exit 0
        fi
    done
    echo "⚠️  No test logs found. Run 'just test' or 'just debug' to generate logs."

# Show full test logs
logs-full:
    #!/usr/bin/env bash
    for f in test.log debug.log "{{tests_dir}}/test.log" "{{security_dir}}/results/"*.log; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            cat "$f"
            echo
        fi
    done

# --- Cleanup -------------------------------------------------------------

# Clean up test artifacts
clean:
    @echo "🔄 Cleaning up test artifacts..."
    @"{{tests_dir}}/test-runner.sh" clean
    @rm -f test.log debug.log
    @find "{{results_dir}}" -type f \( -name '*.log' -o -name '*.tmp' \) -delete 2>/dev/null || true
    @docker system prune -f >/dev/null 2>&1 || true
    @echo "✅ Cleanup completed"

# Deep clean including Docker images, venv, pytest cache
clean-all: clean
    @echo "🔄 Performing deep cleanup..."
    @docker image prune -f >/dev/null 2>&1 || true
    @docker volume prune -f >/dev/null 2>&1 || true
    @rm -rf "{{security_dir}}/.venv" .pytest_cache
    @find . -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
    @find . -name '*.pyc' -delete 2>/dev/null || true
    @echo "✅ Deep cleanup completed"

# Clean only Docker resources
clean-docker:
    @echo "🔄 Cleaning Docker resources..."
    @docker container prune -f >/dev/null 2>&1 || true
    @docker image prune -f >/dev/null 2>&1 || true
    @docker volume prune -f >/dev/null 2>&1 || true
    @echo "✅ Docker cleanup completed"

# --- Docker helpers ------------------------------------------------------

# Pull required Docker images
docker-pull:
    @echo "📥 Pulling {{docker_image}}..."
    @docker pull {{docker_image}}
    @echo "✅ Docker image pulled"

# Show Docker resource usage
docker-status:
    @echo "🐳 Docker status"
    @docker --version
    @docker system df 2>/dev/null || echo "Unable to get disk usage"

# Optimize Docker setup for testing
docker-optimize: docker-pull
    @echo "🔄 Optimizing Docker..."
    @docker system prune -f >/dev/null 2>&1 || true
    @docker image ls {{docker_image}} --format "table {{{{.Repository}}}}\t{{{{.Tag}}}}\t{{{{.Size}}}}"
    @echo "✅ Docker optimization completed"

# --- Validation / Linting ------------------------------------------------

# Validate action.yml
validate-action:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f action.yml ] || { echo "❌ action.yml not found"; exit 1; }
    if command -v yamllint >/dev/null 2>&1; then
        yamllint action.yml
        echo "✅ YAML syntax valid"
    else
        python3 -c "import yaml; yaml.safe_load(open('action.yml'))"
        echo "✅ Basic YAML syntax valid"
    fi
    python3 -c "import yaml; a=yaml.safe_load(open('action.yml')); missing=[f for f in ['name','description','inputs','runs'] if f not in a]; exit(1) if missing else print('✅ All required fields present')"

# Validate workflow files
validate-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    count=0
    shopt -s nullglob
    for f in .github/workflows/*.yml .github/workflows/*.yaml; do
        count=$((count + 1))
        echo "🔍 Checking $f..."
        if command -v yamllint >/dev/null 2>&1; then
            yamllint "$f"
        else
            python3 -c "import yaml; yaml.safe_load(open('$f'))"
        fi
        echo "  ✅ $f"
    done
    if [ "$count" -eq 0 ]; then
        echo "⚠️  No workflow files found"
    else
        echo "✅ Validated $count workflow files"
    fi

# Lint GitHub Actions workflows with actionlint
lint-workflows:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v actionlint >/dev/null 2>&1; then
        actionlint 2>&1 | grep -E "^[^|]*: (error|warning):" | grep -v -E "(SC2129:style|SC2001:style|SC2086:info)" \
            || echo "✅ No actionlint issues"
    elif docker info >/dev/null 2>&1; then
        docker run --rm -v "$PWD:/repo" --workdir /repo rhysd/actionlint:latest 2>&1 \
            | grep -E "^[^|]*: (error|warning):" | grep -v -E "(SC2129:style|SC2001:style|SC2086:info)" \
            || echo "✅ No actionlint issues"
    else
        echo "⚠️  actionlint not available — install locally or start Docker"
    fi

# Install zizmor for local GitHub Actions security audits
install-zizmor:
    @python3 -m pip install --user "zizmor=={{zizmor_version}}"

# Audit GitHub Actions workflows and composite actions with zizmor
lint-zizmor:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v zizmor >/dev/null 2>&1; then
        echo "❌ zizmor is not installed. Run 'just install-zizmor'."
        exit 1
    fi
    zizmor --strict-collection --no-exit-codes action.yml .github/workflows

# Validate security test configuration
validate-security:
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f "{{security_dir}}/requirements.txt" ] || { echo "❌ Security requirements.txt not found"; exit 1; }
    [ -f "{{security_dir}}/pytest.ini" ]       || { echo "❌ pytest.ini not found"; exit 1; }
    [ -f "{{security_dir}}/test_action_boundary.py" ] || { echo "❌ test_action_boundary.py not found"; exit 1; }
    echo "✅ Security configuration validated"

# Run all linting and validation checks
lint: test-unit lint-workflows validate-action validate-workflows validate-security
    @echo "✅ All linting and validation completed"

# --- Developer helpers ---------------------------------------------------

# Install act + run setup
dev-setup: install-act setup
    @echo "✅ Development environment ready"
    @echo ""
    @echo "  just test-basic     # Quick basic test"
    @echo "  just test-security  # Security validation"
    @echo "  just test           # Full integration suite"
    @echo "  just clean          # Cleanup"

# Watch files and rerun fast tests on change
watch:
    #!/usr/bin/env bash
    command -v inotifywait >/dev/null 2>&1 || { echo "❌ inotifywait not found (apt-get install inotify-tools)"; exit 1; }
    echo "Watching for changes..."
    while inotifywait -e modify action.yml .github/workflows/*.yml; do
        just test-fast
    done

# Generate a test report
report: test
    #!/usr/bin/env bash
    set -euo pipefail
    {
        echo "# Test Report"
        echo
        echo "Generated on: $(date)"
        echo
        if [ -f tests/results/summary.json ]; then
            echo "## Results"
            cat tests/results/summary.json
        fi
    } > test-report.md
    echo "Report generated: test-report.md"

# Run performance benchmarks
benchmark: setup
    @echo "🔄 Running performance benchmarks..."
    @"{{tests_dir}}/test-runner.sh" performance
    @echo "✅ Benchmark results saved to tests/results/"

# --- Environment setup (per-platform) ------------------------------------

# Install dependencies in GitHub Codespaces
github-codespaces:
    @sudo apt-get update
    @sudo apt-get install -y docker.io jq curl
    @just install-act
    @just setup

# Install dependencies on Ubuntu/Debian
ubuntu:
    @sudo apt-get update
    @sudo apt-get install -y docker.io jq curl inotify-tools yamllint
    @sudo usermod -aG docker $USER
    @just install-act
    @echo "Note: actionlint is available via Docker (see lint-workflows)"
    @echo "Please log out and back in for Docker group changes"

# Install dependencies on macOS (via Homebrew)
macos:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v brew >/dev/null 2>&1; then
        brew install jq curl yamllint actionlint just
        echo "✅ Dependencies installed via Homebrew"
    else
        echo "❌ Homebrew not found. Install from https://brew.sh"
        exit 1
    fi
    just install-act
    echo "Please install Docker Desktop from https://docker.com"

# --- Status --------------------------------------------------------------

# Show detailed test environment status
status:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════"
    echo "    Test Environment Status Report    "
    echo "═══════════════════════════════════════"
    echo
    echo "🐳 Docker:"
    if docker info >/dev/null 2>&1; then
        echo "  ✅ Running ($(docker --version | cut -d' ' -f3 | tr -d ,))"
        echo "  📊 Images: $(docker images -q | wc -l), Containers: $(docker ps -q | wc -l) running"
    else
        echo "  ❌ Not running"
    fi
    echo
    echo "🔧 Tools:"
    command -v act >/dev/null 2>&1 && echo "  ✅ act: $(act --version 2>/dev/null)" || echo "  ❌ act: not installed (just install-act)"
    command -v jq  >/dev/null 2>&1 && echo "  ✅ jq: $(jq --version)"                 || echo "  ❌ jq: not installed"
    command -v python3 >/dev/null 2>&1 && echo "  ✅ python: $(python3 --version | cut -d' ' -f2)" || echo "  ❌ python: not installed"
    echo
    echo "📁 Project files:"
    [ -f action.yml ] && echo "  ✅ action.yml ($(wc -l < action.yml) lines)" || echo "  ❌ action.yml missing"
    [ -f .github/workflows/test-opengrep-action.yml ] && echo "  ✅ Test workflow present" || echo "  ❌ Test workflow missing"
    [ -f "{{tests_dir}}/test-runner.sh" ] && echo "  ✅ test-runner.sh present" || echo "  ❌ test-runner.sh missing"
    echo
    echo "🔬 Test env:"
    [ -d "{{results_dir}}" ] && echo "  ✅ Results dir ($(find "{{results_dir}}" -type f 2>/dev/null | wc -l) files)" || echo "  ⚠️  Results dir not created"
    [ -d "{{security_dir}}/.venv" ] && echo "  ✅ Security venv present" || echo "  ⚠️  Security venv not created"
    echo
    [ "${CI:-}" = "true" ] && echo "🤖 CI environment detected" || echo "🖥️  Local environment"
    [ "${GITHUB_ACTIONS:-}" = "true" ] && echo "🐙 Running in GitHub Actions"
    echo "  📂 $(pwd)"
    echo "═══════════════════════════════════════"

# --- Release management --------------------------------------------------

# Show current version and release status
release-status:
    @echo "Release Status"
    @echo "=============="
    @echo "Current version: $(git tag --sort=-version:refname | head -n1 || echo 'No tags found')"
    @echo "Git status:"
    @git status --porcelain || echo "No changes"
    @echo ""
    @./scripts/release.sh status

# Prepare a new release: just release-prepare patch|minor|major|prerelease [suffix]
release-prepare type suffix="":
    @echo "Preparing {{type}} release..."
    @./scripts/release.sh prepare {{type}} {{ if suffix != "" { "--prerelease-suffix " + suffix } else { "" } }}

# Create a release tag: just release-tag v1.2.3
release-tag version:
    @echo "Creating release tag {{version}}..."
    @./scripts/release.sh tag {{version}}

# Check if ready for release
release-check:
    @echo "Release Readiness Check"
    @echo "======================="
    @./scripts/release.sh validate "$(git tag --sort=-version:refname | head -n1 || echo v0.0.0)"
    @just test-basic
    @echo "✅ Ready for release"

# Dry-run a release: just release-dry-run patch
release-dry-run type:
    @./scripts/release.sh prepare {{type}} --dry-run

# Show release management help
release-help:
    @echo "Release Management"
    @echo "=================="
    @echo "  just release-status                   # Show current version"
    @echo "  just release-prepare patch            # Prepare patch release"
    @echo "  just release-prepare minor            # Prepare minor release"
    @echo "  just release-prepare major            # Prepare major release"
    @echo "  just release-prepare prerelease beta  # Prerelease with suffix"
    @echo "  just release-tag v1.2.3               # Create release tag"
    @echo "  just release-check                    # Check readiness"
    @echo "  just release-dry-run patch            # Preview without changes"
    @echo ""
    @echo "See RELEASE.md for full documentation."
