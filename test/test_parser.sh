#!/usr/bin/env bash
# Test suite for safe-gitignore parser
# Run with: ./test/test_parser.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source common functions
source "${PROJECT_ROOT}/lib/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for test output
TEST_PASS="${GREEN}PASS${NC}"
TEST_FAIL="${RED}FAIL${NC}"

# Test helper functions
increment_run() { TESTS_RUN=$((TESTS_RUN + 1)); }
increment_pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); }
increment_fail() { TESTS_FAILED=$((TESTS_FAILED + 1)); }

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    increment_run
    if [[ "$expected" == "$actual" ]]; then
        increment_pass
        echo -e "  ${TEST_PASS}: ${message}"
        return 0
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: ${message}"
        echo "    Expected: '${expected}'"
        echo "    Actual:   '${actual}'"
        return 0  # Don't fail the test suite on assertion failure
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    increment_run
    if [[ "$haystack" == *"$needle"* ]]; then
        increment_pass
        echo -e "  ${TEST_PASS}: ${message}"
        return 0
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: ${message}"
        echo "    Expected to contain: '${needle}'"
        echo "    Actual: '${haystack}'"
        return 0
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    increment_run
    if [[ "$haystack" != *"$needle"* ]]; then
        increment_pass
        echo -e "  ${TEST_PASS}: ${message}"
        return 0
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: ${message}"
        echo "    Expected NOT to contain: '${needle}'"
        echo "    Actual: '${haystack}'"
        return 0
    fi
}

assert_empty() {
    local value="$1"
    local message="${2:-}"

    increment_run
    if [[ -z "$value" ]]; then
        increment_pass
        echo -e "  ${TEST_PASS}: ${message}"
        return 0
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: ${message}"
        echo "    Expected empty, got: '${value}'"
        return 0
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-}"

    increment_run
    if [[ -n "$value" ]]; then
        increment_pass
        echo -e "  ${TEST_PASS}: ${message}"
        return 0
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: ${message}"
        echo "    Expected non-empty value"
        return 0
    fi
}

# ============================================================================
# Parser Tests
# ============================================================================

test_parse_sample_gitignore() {
    echo "Testing: parse_safe_patterns with sample.gitignore"

    local result
    result=$(parse_safe_patterns "${SCRIPT_DIR}/fixtures/sample.gitignore")

    assert_contains "$result" ".env" "Should find .env"
    assert_contains "$result" "config/secrets.yml" "Should find config/secrets.yml"
    assert_contains "$result" "*.key" "Should find *.key pattern"
    assert_contains "$result" ".credentials" "Should find .credentials"
    assert_contains "$result" "some/deep/path/secret.json" "Should find deep path"

    assert_not_contains "$result" "node_modules" "Should NOT include node_modules"
    assert_not_contains "$result" "*.log" "Should NOT include *.log"
    assert_not_contains "$result" "comment" "Should NOT include comment lines"
}

test_parse_empty_gitignore() {
    echo "Testing: parse_safe_patterns with empty.gitignore (no #safe tags)"

    local result
    result=$(parse_safe_patterns "${SCRIPT_DIR}/fixtures/empty.gitignore")

    assert_empty "$result" "Should return empty for gitignore without #safe tags"
}

test_parse_nonexistent_gitignore() {
    echo "Testing: parse_safe_patterns with nonexistent file"

    local result
    result=$(parse_safe_patterns "/nonexistent/path/.gitignore")

    assert_empty "$result" "Should return empty for nonexistent file"
}

test_parse_edge_cases() {
    echo "Testing: parse_safe_patterns with edge-cases.gitignore"

    local result
    result=$(parse_safe_patterns "${SCRIPT_DIR}/fixtures/edge-cases.gitignore")

    # Various whitespace
    assert_contains "$result" ".env" "Should handle no space before #safe"
    assert_contains "$result" ".env2" "Should handle single space"
    assert_contains "$result" ".env3" "Should handle double space"
    assert_contains "$result" ".env4" "Should handle tab"
    assert_contains "$result" ".env5" "Should handle trailing whitespace"

    # Negation
    assert_contains "$result" "!important.env" "Should handle negation patterns"

    # Special characters
    assert_contains "$result" "config[1].json" "Should handle brackets"
    assert_contains "$result" "data?.txt" "Should handle question mark"
}

# ============================================================================
# Config Tests
# ============================================================================

test_read_config() {
    echo "Testing: read_config function"

    # Create a temp directory with config
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Initialize git repo
    cd "$tmp_dir"
    git init --quiet

    # Create config file
    cat > ".safe-gitignore.conf" << 'EOF'
SAFE_REMOTE=git@github.com:test/repo.git
SAFE_PROJECT_NAME=test-project
SAFE_COMMIT_MSG="Custom: \$DATE"
EOF

    # Test reading values
    local remote
    remote=$(read_config "SAFE_REMOTE" "")
    assert_equals "git@github.com:test/repo.git" "$remote" "Should read SAFE_REMOTE"

    local project
    project=$(read_config "SAFE_PROJECT_NAME" "")
    assert_equals "test-project" "$project" "Should read SAFE_PROJECT_NAME"

    # Test default value
    local missing
    missing=$(read_config "NONEXISTENT" "default-value")
    assert_equals "default-value" "$missing" "Should return default for missing key"

    cd - > /dev/null
    rm -rf "$tmp_dir"
}

# ============================================================================
# URL Validation Tests
# ============================================================================

test_validate_remote_url() {
    echo "Testing: validate_remote_url function"

    # Valid SSH URL
    increment_run
    if validate_remote_url "git@github.com:user/repo.git"; then
        increment_pass
        echo -e "  ${TEST_PASS}: SSH URL should be valid"
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: SSH URL should be valid"
    fi

    # Valid HTTPS URL
    increment_run
    if validate_remote_url "https://github.com/user/repo.git"; then
        increment_pass
        echo -e "  ${TEST_PASS}: HTTPS URL should be valid"
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: HTTPS URL should be valid"
    fi

    # Invalid URL
    increment_run
    if ! validate_remote_url "not-a-url"; then
        increment_pass
        echo -e "  ${TEST_PASS}: Invalid URL should fail"
    else
        increment_fail
        echo -e "  ${TEST_FAIL}: Invalid URL should fail"
    fi
}

# ============================================================================
# File Matching Tests
# ============================================================================

test_find_matching_files() {
    echo "Testing: find_matching_files function"

    # Create temp directory with test files
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Create test files
    touch "${tmp_dir}/.env"
    mkdir -p "${tmp_dir}/config"
    touch "${tmp_dir}/config/secrets.yml"
    touch "${tmp_dir}/server.key"
    touch "${tmp_dir}/client.key"
    mkdir -p "${tmp_dir}/deep/nested/path"
    touch "${tmp_dir}/deep/nested/path/secret.json"

    # Test literal file
    local result
    result=$(find_matching_files ".env" "$tmp_dir")
    assert_contains "$result" ".env" "Should find literal .env"

    # Test path pattern
    result=$(find_matching_files "config/secrets.yml" "$tmp_dir")
    assert_contains "$result" "secrets.yml" "Should find path pattern"

    # Test glob pattern
    result=$(find_matching_files "*.key" "$tmp_dir")
    assert_contains "$result" "server.key" "Should find server.key with glob"
    assert_contains "$result" "client.key" "Should find client.key with glob"

    rm -rf "$tmp_dir"
}

# ============================================================================
# Integration Tests
# ============================================================================

test_full_workflow() {
    echo "Testing: Full workflow integration"

    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)

    cd "$tmp_dir"

    # Initialize git repo
    git init --quiet
    git config user.email "test@test.com"
    git config user.name "Test"

    # Create .gitignore with #safe tags
    cat > .gitignore << 'EOF'
.env #safe
secrets/*.json #safe
node_modules/
EOF

    # Create the files
    echo "SECRET=value" > .env
    mkdir -p secrets
    echo '{"key": "value"}' > secrets/config.json

    # Commit
    git add .gitignore
    git commit --quiet -m "Initial commit"

    # Test get_safe_files
    local files
    files=$(get_safe_files)

    assert_contains "$files" ".env" "Should find .env in safe files"

    cd - > /dev/null
    rm -rf "$tmp_dir"
}

# ============================================================================
# Run Tests
# ============================================================================

main() {
    echo "=========================================="
    echo "safe-gitignore test suite"
    echo "=========================================="
    echo ""

    test_parse_sample_gitignore
    echo ""

    test_parse_empty_gitignore
    echo ""

    test_parse_nonexistent_gitignore
    echo ""

    test_parse_edge_cases
    echo ""

    test_read_config
    echo ""

    test_validate_remote_url
    echo ""

    test_find_matching_files
    echo ""

    test_full_workflow
    echo ""

    echo "=========================================="
    echo "Results: ${TESTS_PASSED}/${TESTS_RUN} passed"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}${TESTS_FAILED} test(s) failed${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
