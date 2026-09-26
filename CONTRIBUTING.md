# Contributing to debian-repo-upload-action

Thanks for your interest in improving this action! Here's how to develop and test changes.

## Development Setup

### Prerequisites
- Docker (for building and testing the container image)
- Git
- A running debian-repo instance (for testing; see below)

### Local Testing

#### Option 1: Quick test with Docker (no debian-repo required)

Build the Docker image locally:
```bash
docker build -t debian-repo-upload-action:dev .
```

Test the basic logic:
```bash
docker run \
  -e INPUT_FILE=/tmp/test.deb \
  -e INPUT_BASE_URL=https://example.com \
  -e INPUT_TOKEN=test-token \
  debian-repo-upload-action:dev
# Will fail on network, but validates input parsing and script structure
```

#### Option 2: Full end-to-end test against a real debian-repo

1. Start a local debian-repo instance (or use a test instance):
   ```bash
   # Example: run debian-repo locally on port 8080
   docker run -p 8080:127.0.0.1:8080 ghcr.io/rossigee/debian-repo:latest
   ```

2. Create a test `.deb` file:
   ```bash
   # Use an existing .deb from your system, or create a minimal one
   cp /path/to/real.deb /tmp/test-package_1.0.0_amd64.deb
   ```

3. Build the action image:
   ```bash
   docker build -t debian-repo-upload-action:dev .
   ```

4. Run the action:
   ```bash
   docker run \
     -v /tmp:/tmp \
     -e INPUT_FILE=/tmp/test-package_1.0.0_amd64.deb \
     -e INPUT_BASE_URL=http://localhost:8080 \
     -e INPUT_TOKEN=your-test-token \
     -e INPUT_SUITE=stable \
     -e INPUT_COMPONENT=main \
     debian-repo-upload-action:dev
   ```

5. Check the output for success:
   - Should see `✅ Successfully uploaded ...`
   - Should output the package metadata (name, version, architecture, SHA256)

## Code Changes

### Editing the entrypoint script

The main logic is in `entrypoint.sh`. When making changes:

1. **Preserve security**: Never log or leak the bearer token
2. **Validate inputs**: Always check required inputs before using them
3. **Handle errors gracefully**: Provide clear error messages for common failures
4. **Test locally**: Use the end-to-end test above to verify changes

### Linting

The action uses `shellcheck` for shell script linting. To lint locally:

```bash
# Install shellcheck
# macOS: brew install shellcheck
# Ubuntu: sudo apt install shellcheck
# Alpine: apk add shellcheck

shellcheck entrypoint.sh
```

The GitHub Actions lint workflow runs automatically on PR, but catching issues locally speeds up development.

## Testing Your Changes

### Before opening a PR, test:

1. **Local build**:
   ```bash
   docker build -t debian-repo-upload-action:test .
   ```

2. **Shell lint**:
   ```bash
   shellcheck entrypoint.sh
   ```

3. **End-to-end upload** (against a test debian-repo instance)

4. **Error cases**:
   - Missing file: `INPUT_FILE=/nonexistent docker run ... debian-repo-upload-action:test`
   - Invalid token: `INPUT_TOKEN=bad docker run ... debian-repo-upload-action:test`
   - Missing base URL: `INPUT_BASE_URL="" docker run ... debian-repo-upload-action:test`

## Documentation Changes

### Editing README.md

- Keep examples up-to-date and tested
- Link to debian-repo documentation for setup instructions
- Document any new inputs or outputs in the table
- Update error handling section if you fix a common issue

### Documenting limitations

If you find an edge case or limitation, please document it in the README under a new "Known Limitations" section or update existing docs.

## Release Process

When ready to release:

1. Update `README.md` with any new features/changes
2. Update `CHANGELOG.md` with a new entry
3. Create a PR with your changes
4. After approval, tag the release:
   ```bash
   git tag v1.x.x
   git push origin v1.x.x
   ```
5. The GitHub Actions `build.yaml` workflow automatically:
   - Builds the Docker image
   - Pushes to `ghcr.io/rossigee/debian-repo-upload-action:v1.x.x`
   - Updates the major version tag (e.g., `v1` always points to the latest `v1.x.x`)

## Questions or Issues?

- Report bugs or request features via GitHub Issues
- For security issues, email ross@golder.org
- Ask questions in GitHub Discussions

Happy hacking! 🚀
