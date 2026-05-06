# Release Guide

This document outlines the release process for the OpenGrep Action.

## Release Workflow Overview

The OpenGrep Action uses automated release workflows with the following components:

1. **Pre-Release Workflow** - Prepares releases and creates preparation PRs
2. **Release Workflow** - Automatically triggered by version tags
3. **Release Script** - Command-line utility for manual release management

## Release Types

### Stable Releases
- **Patch** (v1.0.0 → v1.0.1) - Bug fixes, security patches
- **Minor** (v1.0.0 → v1.1.0) - New features, backward compatible
- **Major** (v1.0.0 → v2.0.0) - Breaking changes

### Pre-releases
- **Alpha** (v1.0.0-alpha.1) - Early development versions
- **Beta** (v1.0.0-beta.1) - Feature-complete, testing phase
- **Release Candidate** (v1.0.0-rc.1) - Final testing before stable

## Automated Release Process

### Method 1: GitHub Actions Workflow (Recommended)

1. **Navigate to Actions tab** in your GitHub repository
2. **Select "Pre-Release" workflow**
3. **Click "Run workflow"** and configure:
   - **Version type**: patch, minor, major, prerelease, or custom
   - **Custom version**: a specific version when `custom` is selected
   - **Prerelease suffix**: alpha, beta, or rc (if prerelease)
   - **Create release**: true for immediate release, false for preparation PR

#### For Immediate Release:
```
Version type: patch
Create release: true
```
This will:
- ✅ Calculate new version
- ✅ Run pre-release tests
- ✅ Create and push tag
- ✅ Trigger release workflow automatically

#### For Preparation PR:
```
Version type: minor
Create release: false
```
This will:
- ✅ Create a preparation branch
- ✅ Create release notes for review
- ✅ Generate changelog
- ✅ Create PR for review

### Method 2: Manual Tag Creation

```bash
# Create and push a version tag
git tag -a v1.2.3 -m "Release v1.2.3: Add new security rules"
git push origin v1.2.3
```

This automatically triggers the release workflow.

## 🛠️ Manual Release Process

### Using the Release Script

The project includes a comprehensive release management script:

```bash
# Check current status
./scripts/release.sh status

# Prepare a patch release
./scripts/release.sh prepare patch

# Prepare a minor release with custom prerelease suffix
./scripts/release.sh prepare prerelease --prerelease-suffix alpha

# Create a tag
./scripts/release.sh tag v1.2.3

# Validate version format
./scripts/release.sh validate v1.2.3-beta.1
```

### Step-by-Step Manual Process

1. **Prepare the release:**
   ```bash
   ./scripts/release.sh prepare minor
   ```

2. **Review changes:**
   ```bash
   git diff
   ```

3. **Commit preparation changes:**
   ```bash
   git add .
   git commit -m "Prepare release v1.2.0"
   ```

4. **Create and push tag:**
   ```bash
   ./scripts/release.sh tag v1.2.0
   ```

## 🔍 Release Workflow Details

When a version tag is pushed, the release workflow automatically:

### 1. Validation Phase
- ✅ Validates tag format (v1.2.3 or v1.2.3-beta.1)
- ✅ Determines if it's a prerelease
- ✅ Extracts version information

### 2. Testing Phase
- ✅ Runs basic tests
- ✅ Runs integration tests
- ✅ Performs comprehensive security scanning
- ✅ Uses the action to scan itself

### 3. Build & Package Phase
- ✅ Creates distribution package
- ✅ Generates checksums (SHA256, SHA512)
- ✅ Prepares release artifacts

### 4. Release Creation
- ✅ Generates comprehensive changelog
- ✅ Creates GitHub release
- ✅ Uploads package and checksums
- ✅ Marks as prerelease if applicable

### 5. Post-Release
- ✅ Updates major version tag (v1, v2, etc.)
- ✅ Runs final security verification
- ✅ Provides usage instructions

## 📦 Release Artifacts

Each release includes:

- **Source Code** - Automatic GitHub archive
- **Distribution Package** - `opengrep-action-vX.Y.Z.tar.gz`
- **Checksums** - `checksums.txt` with SHA256/SHA512
- **Security Scan Results** - JSON and SARIF workflow artifacts
- **Changelog** - Automatically generated
- **Usage Examples** - In release notes

## 🔒 Security Considerations

### Automated Security Scanning
Every release is automatically scanned for:
- Security vulnerabilities
- Secret leaks
- Code quality issues
- Compliance violations

### Verification
Users can verify release integrity:

```bash
# Download checksums
curl -L https://github.com/platform-sec/opengrep-action/releases/download/v1.2.3/checksums.txt

# Verify package
sha256sum -c checksums.txt
```

### Security Scan Results
- Available as workflow artifacts
- JSON and SARIF reports uploaded automatically
- Release artifacts include scan results for review

## 📋 Release Checklist

### Pre-Release
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Security scan clean
- [ ] Release notes reviewed
- [ ] Changelog reviewed

### During Release
- [ ] Tag created with correct format
- [ ] Release workflow triggered
- [ ] All jobs completed successfully
- [ ] Artifacts uploaded

### Post-Release
- [ ] Release notes reviewed
- [ ] Major version tag updated
- [ ] Usage examples tested
- [ ] Documentation reflects new version

## Troubleshooting

### Release Workflow Fails

1. **Check workflow logs** in Actions tab
2. **Common issues:**
   - Test failures → Fix tests and re-tag
   - Security issues → Address vulnerabilities
   - Invalid tag format → Use v1.2.3 format

### Tag Already Exists

```bash
# Delete local and remote tag
git tag -d v1.2.3
git push origin :refs/tags/v1.2.3

# Create new tag
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

### Major Version Tag Issues

The workflow automatically manages major version tags (v1, v2). If there are issues:

```bash
# Manually update major version tag
git tag -f v1 v1.2.3
git push origin v1 --force
```

## Version Strategy

### Semantic Versioning
We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** - Breaking changes
- **MINOR** - New features, backward compatible
- **PATCH** - Bug fixes, security patches

### Prerelease Naming
- **alpha** - Early development, unstable
- **beta** - Feature complete, testing needed
- **rc** - Release candidate, final testing

### Major Version Tags
- Users should reference the full release commit SHA in workflows
- Major version tags may be maintained for compatibility
- Full commit SHA pins provide immutable production references

## Hotfix Process

For critical security fixes:

1. **Create hotfix branch from tag:**
   ```bash
   git checkout -b hotfix/v1.2.4 v1.2.3
   ```

2. **Apply fix and test:**
   ```bash
   # Make changes
   ./scripts/release.sh prepare patch --no-tests
   ```

3. **Create tag:**
   ```bash
   git commit -m "Hotfix: Critical security patch"
   ./scripts/release.sh tag v1.2.4
   ```

## Support

For release-related issues:
- Check [GitHub Issues](https://github.com/platform-sec/opengrep-action/issues)
- Review [Security Policy](SECURITY.md)
- Contact maintainers via discussions
