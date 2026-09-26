#!/bin/sh
# Simple test suite for entrypoint.sh

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

echo "Running entrypoint.sh validation tests..."
echo ""

# Test 1: Shell syntax check
if shellcheck entrypoint.sh >/dev/null 2>&1; then
  echo "${GREEN}✓${NC} Shell syntax validation"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} Shell syntax validation"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Key functions exist
if grep -q "^error()" entrypoint.sh; then
  echo "${GREEN}✓${NC} error() function defined"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} error() function defined"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: warn function exists
if grep -q "^warn()" entrypoint.sh; then
  echo "${GREEN}✓${NC} warn() function defined"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} warn() function defined"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Validates base-url
if grep -q "base-url input is required" entrypoint.sh; then
  echo "${GREEN}✓${NC} Validates base-url input"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} Validates base-url input"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Validates token
if grep -q "token input is required" entrypoint.sh; then
  echo "${GREEN}✓${NC} Validates token input"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} Validates token input"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Handles multiple files
if grep -q "FILE_LIST" entrypoint.sh && grep -q "while.*read -r deb_file" entrypoint.sh; then
  echo "${GREEN}✓${NC} Multi-file handling implemented"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} Multi-file handling implemented"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 7: Glob pattern support
if grep -q "eval echo" entrypoint.sh; then
  echo "${GREEN}✓${NC} Glob pattern expansion"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} Glob pattern expansion"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 8: Curl upload with auth header
if grep -q 'Authorization: Bearer' entrypoint.sh; then
  echo "${GREEN}✓${NC} Bearer token authentication"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} Bearer token authentication"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: JSON response parsing
if grep -q "jq -r '.package" entrypoint.sh; then
  echo "${GREEN}✓${NC} JSON response parsing"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} JSON response parsing"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 10: GITHUB_OUTPUT support
if grep -q "GITHUB_OUTPUT" entrypoint.sh; then
  echo "${GREEN}✓${NC} GitHub Actions output support"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo "${RED}✗${NC} GitHub Actions output support"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
fi
