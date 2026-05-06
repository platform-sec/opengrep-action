# Contributing to OpenGrep Action

Thank you for your interest in contributing to the OpenGrep Action!

## Quick Start for Contributors

### 1. Development Setup

```bash
# Clone the repository
git clone https://github.com/platform-sec/opengrep-action
cd opengrep-action

# One-command setup (installs dependencies, sets up testing)
just dev-setup

# Verify setup
just test-basic
```

### 2. Development Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes
# ... edit files ...

# Test your changes
just test                    # Integration test suite (alias of just test-integration)
just test-security          # Security validation
just validate-action        # YAML validation

# For full comprehensive coverage (integration + security + performance + benchmarks)
# use: just test-full

# Commit with conventional commits
git commit -m "feat: add new security validation"
git push origin feature/your-feature-name
```

### 3. Pull Request Process

1. **Create PR** with descriptive title and template
2. **Tests pass** - All CI checks must be green
3. **Security review** - Security-sensitive changes need extra review
4. **Documentation** - Update docs if needed
5. **Code review** - At least one maintainer approval required

## Contribution Types

### Bug Fixes
- Fix broken functionality
- Improve error handling
- Performance improvements
- Security patches

### New Features
- New input options
- Output format support
- Integration improvements
- Advanced configuration options

### Documentation
- Fix typos or unclear instructions
- Add examples
- Improve troubleshooting guides
- Enhance API documentation

### Testing
- Add test cases
- Improve test coverage
- Performance benchmarks
- Security testing

### Infrastructure
- CI/CD improvements
- Development tooling
- Build process optimization
- Release automation

## Security Considerations

This is a **security-focused project**. All contributions must maintain the highest security standards:

### Security-Critical Areas

**Input Validation** (High Risk)
```bash
# All user inputs must be validated
- Action inputs (patterns, targets, flags)
- File paths and names
- Command-line arguments
```

**Command Execution** (High Risk)  
```bash
# Never allow arbitrary command execution
- Use arrays for command building
- Validate all arguments
- Escape shell metacharacters
```

**File Operations** (Medium Risk)
```bash
# Prevent path traversal attacks
- Validate file paths
- Use relative paths only
- Check for dangerous patterns (../, absolute paths)
```

### Security Review Process

1. **All PRs** touching security-sensitive code require **security team review**
2. **Security-critical changes** require **two maintainer approvals**
3. **Input handling changes** require **additional testing**
4. **Command execution changes** require **penetration testing**

## Testing Requirements

### Minimum Testing Standards

All contributions must include appropriate tests:

```bash
# (Examples – adapt names to your feature)
# Integration test jobs (GitHub Actions): modify .github/workflows/test-opengrep-action.yml

# Security (pytest) tests
tests/security/test_your_security_feature.py

# Property-based / fuzz tests (pytest)
tests/security/test_property_based_security.py
```

### Test Categories

**Unit Tests**
The repository maintains a small Bats unit-test layer for shared shell
validators in `scripts/validators.sh`. Keep unit tests focused on reusable
helpers that:
- Mock external tools
- Run in <30 seconds
- Avoid network / external side effects

**Integration Tests** 
- Test complete workflows
- Real OpenGrep installation
- Realistic vulnerable applications

**Security Tests**
- Input validation testing
- Command injection attempts
- Path traversal testing
- Error handling validation

**Performance Tests**
- Large codebase handling
- Memory usage validation
- Timeout behavior
- Resource limits

### Running Tests

```bash
# Quick smoke test (basic functionality)
just test-basic

# Validator unit tests (Bats)
just test-unit

# Default integration test suite (alias: just test)
just test-integration

# Comprehensive security validation tests (pytest)
just test-security

# Performance test category (functional performance assertions)
just test-performance

# Benchmark harness (separate from test-performance)
just benchmark

# Fast combined suite (basic + quick security subset)
just test-fast

# Aggregate: integration + security (legacy aggregate)
just test-all

# Full comprehensive suite (parallel categories + security + performance + benchmarks)
just test-full
```

Notes:
- just test is an alias of just test-integration.
- test-performance runs performance-oriented tests; benchmark runs the benchmarking harness.
- test-all omits performance and benchmarks; use test-full for the maximum coverage suite.
- test-fast is optimized for rapid local iteration (basic + quick security subset).
- Unit tests cover shared shell helpers; action behavior is covered by integration (act)
  and security (pytest) layers.

### Documentation Style

```markdown
# Good - Clear, actionable, with examples
## Input Validation

All user inputs are validated before use:

- **Severity levels**: Must be `INFO`, `WARNING`, or `ERROR`
- **File paths**: Must be relative, no `../` allowed
- **Patterns**: Alphanumeric and basic punctuation only

Example:
\`\`\`yaml
severity: 'WARNING'    # Valid
severity: 'INVALID'    # Will fail validation
\`\`\`

# Bad - Vague, no examples
## Validation
Inputs are checked.
```

## Breaking Changes

Changes that break existing functionality require special handling:

### Major Version Changes (v1 → v2)
- API changes (input/output modifications)
- Behavior changes (different defaults)
- Removed features

### Minor Version Changes (v1.1 → v1.2)
- New features (backward compatible)
- New inputs (with defaults)
- Performance improvements

### Patch Version Changes (v1.1.0 → v1.1.1)
- Bug fixes
- Documentation updates
- Security patches

### Breaking Change Process

1. **RFC Issue**: Create issue with `[RFC]` prefix
2. **Community Discussion**: Allow 2+ weeks for feedback
3. **Migration Guide**: Document upgrade path
4. **Deprecation Period**: Mark old features as deprecated first
5. **Coordinated Release**: Plan release with advance notice

## Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format: type(scope): description

# Examples:
feat: add support for custom OpenGrep patterns
fix: resolve path traversal vulnerability in target validation  
docs: update configuration examples with security best practices
test: add integration tests for Node.js projects
refactor: improve error handling in input validation
security: patch command injection in additional-args processing
```

### Commit Types
- `feat:` New features
- `fix:` Bug fixes  
- `docs:` Documentation only changes
- `test:` Adding missing tests or correcting existing tests
- `refactor:` Code change that neither fixes a bug nor adds a feature
- `security:` Security-related changes
- `perf:` Performance improvements
- `ci:` Changes to CI configuration files and scripts

### Scopes (optional)
- `validation:` Input validation logic
- `security:` Security-related functionality  
- `testing:` Test infrastructure
- `docs:` Documentation improvements
- `ci:` Continuous integration

## Release Process

### Automated Releases

Releases are automated based on conventional commits:

- **feat:** → Minor version bump (1.1.0 → 1.2.0)
- **fix:** → Patch version bump (1.1.0 → 1.1.1)  
- **feat!:** or **BREAKING CHANGE:** → Major version bump (1.1.0 → 2.0.0)

### Manual Release Steps (Maintainers)

1. **Prepare Release**
   ```bash
   # Verify all tests pass
   # Review security implications
   ```

2. **Create Release**
   ```bash
   git tag -a v1.2.0 -m "Release v1.2.0: Add custom rules support"
   git push origin v1.2.0
   ```

3. **Update Major Version Tag**
   ```bash
   git tag -f v1 
   git push origin v1 --force
   ```

### Release Notes

Release notes are generated automatically from conventional commits by
`.github/workflows/pre-release.yml` and `.github/workflows/release.yml`, and
published on the GitHub Releases page. There is no repo-root `CHANGELOG.md`
to maintain.
