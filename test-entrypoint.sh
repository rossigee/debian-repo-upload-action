#!/bin/sh
# Simple test suite for entrypoint.sh

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Test framework
assert_exit_code() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" = "$expected" ]; then
    echo "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "${RED}✗${NC} $test_name (expected: $expected, got: $actual)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  local test_name="$1"
  local string="$2"
  local substring="$3"

  if echo "$string" | grep -q "$substring"; then
    echo "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "${RED}✗${NC} $test_name"
    echo "  Expected to find: $substring"
    echo "  In: $string"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Setup test environment
setup_test_env() {
  TEST_DIR=$(mktemp -d)
  export TEST_DIR

  # Create mock .deb files
  touch "$TEST_DIR/package1_1.0_amd64.deb"
  touch "$TEST_DIR/package2_1.0_amd64.deb"
  touch "$TEST_DIR/package3_1.0_arm64.deb"
}

cleanup_test_env() {
  rm -rf "$TEST_DIR"
}

# Test input validation
test_missing_base_url() {
  # Test: error when base-url is missing
  FILE="test.deb" BASE_URL="" TOKEN="token" \
    bash -c 'source ./entrypoint.sh 2>&1' > /tmp/test_output.txt 2>&1 || true

  assert_contains "Missing base-url error" "$(cat /tmp/test_output.txt)" "base-url input is required"
}

test_missing_token() {
  # Test: error when token is missing
  FILE="test.deb" BASE_URL="https://example.com" TOKEN="" \
    bash -c 'source ./entrypoint.sh 2>&1' > /tmp/test_output.txt 2>&1 || true

  assert_contains "Missing token error" "$(cat /tmp/test_output.txt)" "token input is required"
}

test_invalid_base_url() {
  # Test: error when base-url doesn't have http(s)://
  FILE="test.deb" BASE_URL="example.com" TOKEN="token" \
    bash -c 'source ./entrypoint.sh 2>&1' > /tmp/test_output.txt 2>&1 || true

  assert_contains "Invalid base-url error" "$(cat /tmp/test_output.txt)" "must start with http"
}

test_no_file_or_files() {
  # Test: error when neither file nor files provided
  FILE="" FILES="" BASE_URL="https://example.com" TOKEN="token" \
    bash -c 'source ./entrypoint.sh 2>&1' > /tmp/test_output.txt 2>&1 || true

  assert_contains "No file/files error" "$(cat /tmp/test_output.txt)" "either 'file' or 'files' input is required"
}

# Test glob pattern handling
test_glob_expansion() {
  setup_test_env
  cd "$TEST_DIR" || exit 1

  # Test: glob pattern should expand
  FILE="package*_amd64.deb" BASE_URL="https://example.com" TOKEN="token" \
    bash -c 'source '"$OLDPWD"'/entrypoint.sh 2>&1' > /tmp/test_output.txt 2>&1 || true

  output=$(cat /tmp/test_output.txt)

  # Check that it found the files (will fail on upload but should expand globs)
  if echo "$output" | grep -q "package1.*package2"; then
    echo "${GREEN}✓${NC} Glob pattern expands to multiple files"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "${RED}✗${NC} Glob pattern should expand"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  cleanup_test_env
}

test_single_file_glob() {
  setup_test_env
  cd "$TEST_DIR" || exit 1

  # Test: glob pattern matching single file
  FILE="package1_*_amd64.deb" BASE_URL="https://example.com" TOKEN="token" \
    bash -c 'source '"$OLDPWD"'/entrypoint.sh 2>&1' > /tmp/test_output.txt 2>&1 || true

  output=$(cat /tmp/test_output.txt)

  if echo "$output" | grep -q "package1_1.0_amd64.deb"; then
    echo "${GREEN}✓${NC} Single file glob pattern"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "${RED}✗${NC} Single file glob pattern"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  cleanup_test_env
}

# Run all tests
echo "Running entrypoint.sh tests..."
echo ""

test_missing_base_url
test_missing_token
test_invalid_base_url
test_no_file_or_files
test_glob_expansion
test_single_file_glob

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
