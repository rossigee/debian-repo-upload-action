#!/bin/sh
set -e

FILE="$1"
BASE_URL="$2"
TOKEN="$3"
SUITE="$4"
COMPONENT="$5"
FAIL_ON_ERROR="${6:-true}"

# Mask the token for security
if command -v echo >/dev/null 2>&1; then
  echo "::add-mask::${TOKEN}"
fi

# Validate inputs
if [ -z "$FILE" ]; then
  echo "Error: file input is required"
  exit 1
fi

if [ -z "$BASE_URL" ]; then
  echo "Error: base-url input is required"
  exit 1
fi

if [ -z "$TOKEN" ]; then
  echo "Error: token input is required"
  exit 1
fi

# Validate file exists
if [ ! -f "$FILE" ]; then
  echo "Error: file '$FILE' not found"
  exit 1
fi

# Build URL with optional query parameters
URL="${BASE_URL}/api/v1/upload"
if [ -n "$SUITE" ] && [ -n "$COMPONENT" ]; then
  URL="${URL}?suite=${SUITE}&component=${COMPONENT}"
elif [ -n "$SUITE" ]; then
  URL="${URL}?suite=${SUITE}"
elif [ -n "$COMPONENT" ]; then
  URL="${URL}?component=${COMPONENT}"
fi

echo "Uploading $FILE to $URL"

# Upload the package
RESPONSE=$(mktemp)
HTTP_CODE=$(curl -sS -w '%{http_code}' -o "$RESPONSE" \
  -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  --data-binary "@${FILE}" \
  "${URL}")

# Handle errors
if [ "$HTTP_CODE" != "200" ]; then
  echo "Upload failed with HTTP $HTTP_CODE"
  if [ -s "$RESPONSE" ]; then
    echo "Server response:"
    cat "$RESPONSE"
  fi
  rm -f "$RESPONSE"

  if [ "$FAIL_ON_ERROR" = "true" ]; then
    exit 1
  else
    exit 0
  fi
fi

# Parse JSON response and extract fields
PACKAGE=$(jq -r '.package // empty' "$RESPONSE")
VERSION=$(jq -r '.version // empty' "$RESPONSE")
ARCHITECTURE=$(jq -r '.architecture // empty' "$RESPONSE")
FILENAME=$(jq -r '.filename // empty' "$RESPONSE")
SHA256=$(jq -r '.checksums.sha256 // empty' "$RESPONSE")
STATUS=$(jq -r '.status // empty' "$RESPONSE")

# Write outputs to GITHUB_OUTPUT
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "package=${PACKAGE}" >> "$GITHUB_OUTPUT"
  echo "version=${VERSION}" >> "$GITHUB_OUTPUT"
  echo "architecture=${ARCHITECTURE}" >> "$GITHUB_OUTPUT"
  echo "filename=${FILENAME}" >> "$GITHUB_OUTPUT"
  echo "sha256=${SHA256}" >> "$GITHUB_OUTPUT"
  echo "status=${STATUS}" >> "$GITHUB_OUTPUT"
fi

# Print success message
echo "✅ Successfully uploaded ${PACKAGE} version ${VERSION} (${ARCHITECTURE})"
echo "   Location: ${FILENAME}"
echo "   SHA256: ${SHA256}"

rm -f "$RESPONSE"
