#!/bin/sh
set -e

FILE="$1"
BASE_URL="$2"
TOKEN="$3"
SUITE="$4"
COMPONENT="$5"
FAIL_ON_ERROR="${6:-true}"

# Mask the token for security
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "::add-mask::${TOKEN}"
fi

# Helper functions
error() {
  echo "❌ Error: $*" >&2
  exit 1
}

warn() {
  echo "⚠️  Warning: $*" >&2
}

# Validate required inputs
[ -n "$FILE" ] || error "file input is required"
[ -n "$BASE_URL" ] || error "base-url input is required"
[ -n "$TOKEN" ] || error "token input is required"

# Validate file exists
[ -f "$FILE" ] || error "file '$FILE' not found"

# Validate file is readable
[ -r "$FILE" ] || error "file '$FILE' is not readable"

# Get file size for validation
FILE_SIZE=$(stat -c%s "$FILE" 2>/dev/null || stat -f%z "$FILE" 2>/dev/null || echo "unknown")
if [ "$FILE_SIZE" != "unknown" ] && [ "$FILE_SIZE" -gt 536870912 ]; then
  error "file is too large ($(($FILE_SIZE / 1024 / 1024))MB, max 512MB)"
fi

# Validate base URL format
case "$BASE_URL" in
  https://* | http://*)
    ;;
  *)
    error "base-url must start with http:// or https://"
    ;;
esac

# Remove trailing slash from base URL
BASE_URL="${BASE_URL%/}"

# Build URL with optional query parameters
URL="${BASE_URL}/api/v1/upload"
QUERY_PARAMS=""

if [ -n "$SUITE" ]; then
  QUERY_PARAMS="${QUERY_PARAMS}${QUERY_PARAMS:+&}suite=${SUITE}"
fi
if [ -n "$COMPONENT" ]; then
  QUERY_PARAMS="${QUERY_PARAMS}${QUERY_PARAMS:+&}component=${COMPONENT}"
fi

if [ -n "$QUERY_PARAMS" ]; then
  URL="${URL}?${QUERY_PARAMS}"
fi

echo "Uploading $(basename "$FILE") to $URL"

# Upload the package
RESPONSE=$(mktemp)
trap "rm -f $RESPONSE" EXIT

HTTP_CODE=$(curl -sS -w '%{http_code}' -o "$RESPONSE" \
  -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  --data-binary "@${FILE}" \
  "${URL}")

# Check for HTTP success
if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Upload failed with HTTP $HTTP_CODE" >&2

  # Try to parse error response
  if [ -s "$RESPONSE" ]; then
    # Check if it's JSON
    if jq empty "$RESPONSE" 2>/dev/null; then
      echo "Server response:" >&2
      jq . "$RESPONSE" >&2
    else
      echo "Server response:" >&2
      cat "$RESPONSE" >&2
    fi
  fi

  if [ "$FAIL_ON_ERROR" = "true" ]; then
    exit 1
  else
    exit 0
  fi
fi

# Verify response is valid JSON and contains expected fields
if ! jq empty "$RESPONSE" 2>/dev/null; then
  error "Server returned invalid JSON response"
fi

# Parse JSON response and extract fields
PACKAGE=$(jq -r '.package // empty' "$RESPONSE")
VERSION=$(jq -r '.version // empty' "$RESPONSE")
ARCHITECTURE=$(jq -r '.architecture // empty' "$RESPONSE")
FILENAME=$(jq -r '.filename // empty' "$RESPONSE")
SHA256=$(jq -r '.checksums.sha256 // empty' "$RESPONSE")
STATUS=$(jq -r '.status // empty' "$RESPONSE")

# Validate required response fields
[ -n "$PACKAGE" ] || warn "package field missing from response"
[ -n "$VERSION" ] || warn "version field missing from response"
[ -n "$ARCHITECTURE" ] || warn "architecture field missing from response"
[ -n "$FILENAME" ] || warn "filename field missing from response"
[ -n "$SHA256" ] || warn "sha256 checksum missing from response"

# Validate status is 'registered'
if [ "$STATUS" != "registered" ]; then
  warn "expected status 'registered', got '$STATUS'"
fi

# Write outputs to GITHUB_OUTPUT
if [ -n "$GITHUB_OUTPUT" ]; then
  {
    echo "package=${PACKAGE}"
    echo "version=${VERSION}"
    echo "architecture=${ARCHITECTURE}"
    echo "filename=${FILENAME}"
    echo "sha256=${SHA256}"
    echo "status=${STATUS}"
  } >> "$GITHUB_OUTPUT"
fi

# Print success message
echo ""
echo "✅ Successfully uploaded ${PACKAGE} ${VERSION}"
if [ -n "$ARCHITECTURE" ]; then
  echo "   Architecture: ${ARCHITECTURE}"
fi
if [ -n "$FILENAME" ]; then
  echo "   Location: ${FILENAME}"
fi
if [ -n "$SHA256" ]; then
  echo "   SHA256: ${SHA256}"
fi
echo ""
