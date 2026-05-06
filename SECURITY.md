# Security Policy

## Supported Versions

We actively support the following versions of the OpenGrep Action:

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting Security Vulnerabilities

We take security vulnerabilities seriously. If you discover a security vulnerability in the OpenGrep Action, please follow responsible disclosure practices.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities by:

1. **Email**: Send details to [security@platformsecurity.dev]
2. **GitHub Security Advisories**: Use the [private vulnerability reporting feature](https://github.com/platform-sec/opengrep-action/security/advisories/new) on GitHub

### What to Include

When reporting a security vulnerability, please include:

- A clear description of the vulnerability
- Steps to reproduce the issue
- Potential impact assessment
- Any suggested fixes (if applicable)
- Your contact information for follow-up

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Fix Timeline**: Varies based on severity and complexity

## Security Considerations

### Action Security Features

This GitHub Action implements several security hardening measures:

#### Input Validation
- All user inputs are validated and sanitized
- File paths are restricted to prevent directory traversal attacks
- Pattern inputs are validated to prevent code injection

#### Container Security
- Runs with minimal privileges
- Uses official base images with security updates
- Implements proper secret handling

#### Output Security
- Sanitizes output to prevent log injection
- Securely handles sensitive data in scan results
- Implements proper error handling without information disclosure

### Best Practices for Users

When using this action, follow these security best practices:

#### Repository Settings
- Limit action permissions using `permissions` in workflow files
- Review action permissions regularly

```yaml
permissions:
  contents: read
  security-events: write
  pull-requests: write
```

#### Workflow Security
- Pin action references to full commit SHAs instead of version tags, branches, or latest aliases
```yaml
# Good - full commit SHA
uses: platform-sec/opengrep-action@52ffd7b1acae92f0bf27d40187f3bbd9ab382b31

# Bad - moving target references such as branches or mutable tags
```

#### Avoiding Common Security Issues

1. **Path Traversal Prevention**
   - Always use relative paths within the repository
   - Validate target directories exist and are within expected bounds

2. **Resource Limits**
   - Set appropriate timeouts to prevent resource exhaustion
   - Use `max-target-bytes` to limit file size processing

3. **Output Handling**
   - Be cautious when processing scan results
   - Sanitize output before displaying in logs or comments

## Dependency Security

### Third-Party Dependencies

This action relies on:
- OpenGrep/Semgrep security scanner
- Official GitHub Actions toolkit
- Node.js runtime environment

### Dependency Management

- Dependencies are regularly updated for security patches
- We use dependabot for automated dependency updates
- All dependencies are scanned for known vulnerabilities

## Incident Response

### Security Incident Process

1. **Detection**: Security issues are identified through various channels
2. **Assessment**: Severity and impact are evaluated
3. **Response**: Immediate containment and fix development
4. **Communication**: Transparent communication with users
5. **Recovery**: Deploy fixes and verify resolution
6. **Learning**: Post-incident review and process improvement

### Severity Classification

- **Critical**: Immediate threat to user security or data
- **High**: Significant security vulnerability with potential for exploitation
- **Medium**: Security vulnerability with limited impact or difficult exploitation
- **Low**: Minor security issues or hardening opportunities

## Security Updates

### Notification Channels

Stay informed about security updates through:

- GitHub Security Advisories
- Release notes for security patches
- Watch this repository for security-related announcements

### Update Process

1. Security fixes are prioritized and fast-tracked
2. Patches are thoroughly tested before release
3. Users are notified through multiple channels
4. Clear upgrade instructions are provided

## Contact Information

For security-related questions or concerns:

- **Security Team**: security@platformsecurity.dev
- **General Issues**: Use GitHub Issues for non-security bugs
- **Documentation**: Refer to README.md for usage questions
