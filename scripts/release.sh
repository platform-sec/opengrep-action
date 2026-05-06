#!/bin/bash
# SPDX-License-Identifier: MIT

# Release Management Script for OpenGrep Action
# This script helps with version management and release preparation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}\n"
}

# Get current version from git tags
get_current_version() {
    local latest
    latest=$(git tag --sort=-version:refname | head -n1)
    if [ -z "$latest" ]; then
        echo "v0.0.0"
    else
        echo "$latest"
    fi
}

# Validate version format
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        print_error "Invalid version format: $version"
        print_error "Expected format: v1.2.3 or v1.2.3-beta.1"
        return 1
    fi
    return 0
}

# Calculate next version
calculate_next_version() {
    local current="$1"
    local bump_type="$2"
    local prerelease_suffix="$3"
    
    # Remove 'v' prefix
    local current_no_v="${current#v}"
    
    case "$bump_type" in
        patch)
            echo "v$(echo "$current_no_v" | awk -F. '{$3 = $3 + 1} 1' OFS=.)"
            ;;
        minor)
            echo "v$(echo "$current_no_v" | awk -F. '{$2 = $2 + 1; $3 = 0} 1' OFS=.)"
            ;;
        major)
            echo "v$(echo "$current_no_v" | awk -F. '{$1 = $1 + 1; $2 = 0; $3 = 0} 1' OFS=.)"
            ;;
        prerelease)
            if [[ "$current_no_v" =~ -([a-zA-Z]+)\.([0-9]+)$ ]]; then
                # Increment existing prerelease
                local prefix="${current_no_v%-*}"
                local suffix="${current_no_v##*-}"
                local pre_type="${suffix%.*}"
                local pre_num="${suffix##*.}"
                echo "v${prefix}-${pre_type}.$((pre_num + 1))"
            else
                # Create new prerelease
                echo "v${current_no_v}-${prerelease_suffix:-beta}.1"
            fi
            ;;
        *)
            print_error "Unknown bump type: $bump_type"
            return 1
            ;;
    esac
}

# Check if working directory is clean
check_clean_working_dir() {
    if [ -n "$(git status --porcelain)" ]; then
        print_error "Working directory is not clean. Please commit or stash changes."
        git status --short
        return 1
    fi
    return 0
}

# Run tests
run_tests() {
    print_header "Running Tests"
    
    if [ -f "$PROJECT_ROOT/justfile" ]; then
        print_status "Running basic tests..."
        (cd "$PROJECT_ROOT" && just test-basic)

        print_status "Running integration tests..."
        (cd "$PROJECT_ROOT" && just test-integration)
    else
        print_warning "No justfile found, skipping tests"
    fi
    
    print_success "All tests passed"
}

# Update version references in files
update_version_references() {
    local new_version="$1"
    
    print_header "Updating Version References"
    
    # Update README.md
    if [ -f "$PROJECT_ROOT/README.md" ]; then
        print_status "Updating README.md..."
        sed -i.bak "s/@v[0-9]\+\.[0-9]\+\.[0-9]\+\(-[a-zA-Z0-9.-]\+\)\?/@$new_version/g" "$PROJECT_ROOT/README.md"
        rm -f "$PROJECT_ROOT/README.md.bak"
    fi
    
    # Update SECURITY.md
    if [ -f "$PROJECT_ROOT/SECURITY.md" ]; then
        print_status "Updating SECURITY.md..."
        sed -i.bak "s/@v[0-9]\+\.[0-9]\+\.[0-9]\+\(-[a-zA-Z0-9.-]\+\)\?/@$new_version/g" "$PROJECT_ROOT/SECURITY.md"
        rm -f "$PROJECT_ROOT/SECURITY.md.bak"
    fi
    
    # Update CONTRIBUTING.md
    if [ -f "$PROJECT_ROOT/CONTRIBUTING.md" ]; then
        print_status "Updating CONTRIBUTING.md..."
        sed -i.bak "s/@v[0-9]\+\.[0-9]\+\.[0-9]\+\(-[a-zA-Z0-9.-]\+\)\?/@$new_version/g" "$PROJECT_ROOT/CONTRIBUTING.md"
        rm -f "$PROJECT_ROOT/CONTRIBUTING.md.bak"
    fi
    
    print_success "Version references updated"
}

# Generate changelog
generate_changelog() {
    local current_version="$1"
    local new_version="$2"
    
    print_header "Generating Changelog"
    
    local changelog_file="$PROJECT_ROOT/CHANGELOG.md"
    local temp_changelog="/tmp/changelog_temp.md"
    
    cat > "$temp_changelog" << EOF
# Changelog

All notable changes to this project will be documented in this file.

## [$new_version] - $(date +%Y-%m-%d)

### Added
$(git log --oneline ${current_version}..HEAD --grep="feat\|feature\|add" --pretty="- %s" | head -10)

### Changed
$(git log --oneline ${current_version}..HEAD --grep="change\|update\|modify" --pretty="- %s" | head -10)

### Fixed
$(git log --oneline ${current_version}..HEAD --grep="fix\|bug" --pretty="- %s" | head -10)

### Security
$(git log --oneline ${current_version}..HEAD --grep="security\|sec\|vuln" --pretty="- %s" | head -5)

### Documentation
$(git log --oneline ${current_version}..HEAD --grep="doc\|docs\|readme" --pretty="- %s" | head -5)

EOF

    # If changelog exists, append the old content
    if [ -f "$changelog_file" ]; then
        echo "" >> "$temp_changelog"
        tail -n +2 "$changelog_file" >> "$temp_changelog"
    fi
    
    mv "$temp_changelog" "$changelog_file"
    print_success "Changelog generated: $changelog_file"
}

# Create release tag
create_release_tag() {
    local version="$1"
    local message="$2"
    
    print_header "Creating Release Tag"
    
    if git tag -l | grep -q "^$version$"; then
        print_error "Tag $version already exists"
        return 1
    fi
    
    git tag -a "$version" -m "${message:-Release $version}"
    print_success "Tag $version created"
    
    read -p "Push tag to origin? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git push origin "$version"
        print_success "Tag pushed to origin"
    else
        print_warning "Tag not pushed. Run 'git push origin $version' manually."
    fi
}

# Show usage
show_usage() {
    cat << EOF
Release Management Script for OpenGrep Action

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  status              Show current version and git status
  prepare [TYPE]      Prepare a new release (patch|minor|major|prerelease)
  tag VERSION         Create a release tag with the specified version
  changelog           Generate changelog for current changes
  update-refs VERSION Update version references in documentation
  validate VERSION    Validate version format

Options:
  --prerelease-suffix SUFFIX  Suffix for prerelease versions (default: beta)
  --no-tests                  Skip running tests
  --dry-run                   Show what would be done without making changes
  --help                      Show this help message

Examples:
  $0 status
  $0 prepare patch
  $0 prepare minor --no-tests
  $0 prepare prerelease --prerelease-suffix alpha
  $0 tag v1.2.3
  $0 validate v1.2.3-beta.1

EOF
}

# Main script logic
main() {
    if [ $# -eq 0 ] || [ "${1:-}" = "--help" ]; then
        show_usage
        exit 0
    fi

    local command="$1"
    shift || true
    
    local prerelease_suffix="beta"
    local skip_tests=false
    local dry_run=false
    local args=()
    
    # Parse options anywhere after the command so documented forms like
    # "prepare patch --no-tests" and "prepare --no-tests patch" both work.
    while [[ $# -gt 0 ]]; do
        case $1 in
            --prerelease-suffix)
                if [ $# -lt 2 ]; then
                    print_error "--prerelease-suffix requires a value"
                    exit 1
                fi
                prerelease_suffix="$2"
                shift 2
                ;;
            --prerelease-suffix=*)
                prerelease_suffix="${1#*=}"
                shift
                ;;
            --no-tests)
                skip_tests=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            --*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    set -- "${args[@]}"
    
    case "$command" in
        status)
            print_header "Current Status"
            echo "Current version: $(get_current_version)"
            echo "Git status:"
            git status --short
            ;;
            
        prepare)
            local bump_type="${1:-patch}"
            
            if [ "$dry_run" = false ]; then
                check_clean_working_dir
            fi
            
            local current_version
            current_version=$(get_current_version)
            local new_version
            new_version=$(calculate_next_version "$current_version" "$bump_type" "$prerelease_suffix")
            
            print_header "Preparing Release"
            echo "Current version: $current_version"
            echo "New version: $new_version"
            echo "Bump type: $bump_type"
            
            if [ "$dry_run" = true ]; then
                print_warning "DRY RUN - No changes will be made"
                exit 0
            fi
            
            if [ "$skip_tests" = false ]; then
                run_tests
            fi
            
            update_version_references "$new_version"
            generate_changelog "$current_version" "$new_version"
            
            print_success "Release preparation complete!"
            print_status "Next steps:"
            echo "1. Review the changes: git diff"
            echo "2. Commit changes: git add . && git commit -m 'Prepare release $new_version'"
            echo "3. Create tag: $0 tag $new_version"
            ;;
            
        tag)
            local version="$1"
            if [ -z "$version" ]; then
                print_error "Version is required"
                show_usage
                exit 1
            fi
            
            validate_version "$version"
            
            if [ "$dry_run" = false ]; then
                check_clean_working_dir
            fi
            
            if [ "$dry_run" = true ]; then
                print_warning "DRY RUN - Tag would be created: $version"
                exit 0
            fi
            
            create_release_tag "$version"
            ;;
            
        changelog)
            local current_version
            current_version=$(get_current_version)
            generate_changelog "$current_version" "unreleased"
            ;;
            
        update-refs)
            local version="$1"
            if [ -z "$version" ]; then
                print_error "Version is required"
                exit 1
            fi
            
            validate_version "$version"
            
            if [ "$dry_run" = true ]; then
                print_warning "DRY RUN - Version references would be updated to: $version"
                exit 0
            fi
            
            update_version_references "$version"
            ;;
            
        validate)
            local version="$1"
            if [ -z "$version" ]; then
                print_error "Version is required"
                exit 1
            fi
            
            if validate_version "$version"; then
                print_success "Version format is valid: $version"
            else
                exit 1
            fi
            ;;
            
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
