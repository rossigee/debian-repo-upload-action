#!/bin/sh
set -e

FILE="$1"
FILES="$2"
BASE_URL="$3"
TOKEN="$4"
SUITE="$5"
COMPONENT="$6"
FAIL_ON_ERROR="${7:-true}"

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
[ -n "$BASE_URL" ] || error "base-url input is required"
[ -n "$TOKEN" ] || error "token input is required"

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

# Determine which files to upload
FILE_LIST=""

if [ -n "$FILE" ]; then
  # Single file input (with glob support)
  # shellcheck disable=SC2086
  FILE_LIST=$(eval echo "$FILE" 2>/dev/null) || error "file glob pattern '$FILE' expanded to nothing"
elif [ -n "$FILES" ]; then
  # Multiple files input (with glob support)
  # Split by space or comma
  for pattern in $(echo "$FILES" | tr ',' ' '); do
    # shellcheck disable=SC2086
    expanded=$(eval echo "$pattern" 2>/dev/null) || error "files glob pattern '$pattern' expanded to nothing"
    FILE_LIST="$FILE_LIST $expanded"
  done
else
  error "either 'file' or 'files' input is required"
fi

# Remove duplicate entries and validate files
FILE_LIST=$(echo "$FILE_LIST" | tr ' ' '\n' | sort -u)

if [ -z "$(echo "$FILE_LIST" | xargs)" ]; then
  error "no .deb files found matching pattern"
fi

# Validate all files before uploading
while IFS= read -r deb_file; do
  [ -z "$deb_file" ] && continue
  [ -f "$deb_file" ] || error "file '$deb_file' not found"
  [ -r "$deb_file" ] || error "file '$deb_file' is not readable"

  # Validate file size
  FILE_SIZE=$(stat -c%s "$deb_file" 2>/dev/null || stat -f%z "$deb_file" 2>/dev/null || echo "unknown")
  if [ "$FILE_SIZE" != "unknown" ] && [ "$FILE_SIZE" -gt 536870912 ]; then
    error "file '$deb_file' is too large ($((FILE_SIZE / 1024 / 1024))MB, max 512MB)"
  fi
done <<EOF
$FILE_LIST
EOF

# Upload each file
FAILED_UPLOADS=0
SUCCESS_UPLOADS=0

echo ""
while IFS= read -r deb_file; do
  [ -z "$deb_file" ] && continue

  echo "⬆️  Uploading $(basename "$deb_file")..."

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

  # Upload the package
  RESPONSE=$(mktemp)
  trap 'rm -f "$RESPONSE"' EXIT

  HTTP_CODE=$(curl -sS -w '%{http_code}' -o "$RESPONSE" \
    -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    --data-binary "@${deb_file}" \
    "${URL}")

  # Check for HTTP success
  if [ "$HTTP_CODE" != "200" ]; then
    echo "   ❌ HTTP $HTTP_CODE" >&2

    # Try to parse error response
    if [ -s "$RESPONSE" ]; then
      if jq empty "$RESPONSE" 2>/dev/null; then
        jq . "$RESPONSE" >&2
      else
        cat "$RESPONSE" >&2
      fi
    fi

    FAILED_UPLOADS=$((FAILED_UPLOADS + 1))

    if [ "$FAIL_ON_ERROR" = "true" ]; then
      exit 1
    fi
    continue
  fi

  # Verify response is valid JSON
  if ! jq empty "$RESPONSE" 2>/dev/null; then
    echo "   ❌ Invalid JSON response" >&2
    FAILED_UPLOADS=$((FAILED_UPLOADS + 1))
    if [ "$FAIL_ON_ERROR" = "true" ]; then
      exit 1
    fi
    continue
  fi

  # Parse JSON response
  PACKAGE=$(jq -r '.package // empty' "$RESPONSE")
  VERSION=$(jq -r '.version // empty' "$RESPONSE")
  ARCHITECTURE=$(jq -r '.architecture // empty' "$RESPONSE")
  FILENAME=$(jq -r '.filename // empty' "$RESPONSE")
  SHA256=$(jq -r '.checksums.sha256 // empty' "$RESPONSE")
  STATUS=$(jq -r '.status // empty' "$RESPONSE")

  # Validate response fields
  if [ -z "$PACKAGE" ] || [ -z "$VERSION" ] || [ -z "$ARCHITECTURE" ]; then
    warn "Response missing expected fields"
  fi

  # Validate status
  if [ "$STATUS" != "registered" ]; then
    warn "Expected status 'registered', got '$STATUS'"
  fi

  # Write outputs to GITHUB_OUTPUT (last file wins)
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

  # Print success
  echo "   ✅ ${PACKAGE} ${VERSION} (${ARCHITECTURE})"
  SUCCESS_UPLOADS=$((SUCCESS_UPLOADS + 1))
done <<EOF
$FILE_LIST
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Upload Summary: ✅ $SUCCESS_UPLOADS succeeded"
if [ "$FAILED_UPLOADS" -gt 0 ]; then
  echo "               ❌ $FAILED_UPLOADS failed"
  if [ "$FAIL_ON_ERROR" = "true" ]; then
    exit 1
  fi
fi
echo ""
