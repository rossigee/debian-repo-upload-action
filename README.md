# debian-repo Upload Action

A reusable GitHub Action (and Gitea Actions-compatible) composite action for uploading Debian packages (`.deb` files) to a [debian-repo](https://github.com/rossigee/debian-repo) instance.

## Features

- ✅ Simple, minimal interface: file, base URL, authentication token
- ✅ Supports custom distribution suites and components
- ✅ Extracts and outputs package metadata (name, version, architecture, checksums)
- ✅ Constant-time token comparison for security
- ✅ Secure token masking in logs
- ✅ Works on GitHub Actions and Gitea Actions runners
- ✅ Minimal Docker container (Alpine + curl + jq)

## Usage

### Basic Example

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-upload:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Debian package
        run: |
          # Your dpkg-buildpackage or equivalent here
          dpkg-buildpackage -us -uc

      - name: Upload to debian-repo
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../your-package_*.deb
          base-url: https://debs.myorgname.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main
```

### Using Outputs

```yaml
      - name: Upload to debian-repo
        id: upload
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: my-app_1.0.0_amd64.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main

      - name: Create GitHub Release
        uses: actions/create-release@v1
        with:
          tag_name: ${{ github.ref }}
          body: |
            Uploaded: ${{ steps.upload.outputs.package }} ${{ steps.upload.outputs.version }}
            Architecture: ${{ steps.upload.outputs.architecture }}
            SHA256: ${{ steps.upload.outputs.sha256 }}
```

### Matrix Build (Multiple Architectures)

```yaml
      - name: Upload to debian-repo
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: my-app_1.0.0_${{ matrix.arch }}.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `file` | ✅ | | Path to the `.deb` file to upload |
| `base-url` | ✅ | | Base URL of the debian-repo instance (e.g., `https://debs.myorgname.com`) |
| `token` | ✅ | | CI bearer token for authentication (store in a GitHub secret) |
| `suite` | | (server default) | Distribution suite (e.g., `stable`, `testing`, `unstable`) |
| `component` | | (server default) | Component (e.g., `main`, `contrib`, `non-free`) |
| `fail-on-error` | | `true` | Whether to fail the step on upload errors (set to `false` to continue on error) |

## Outputs

| Output | Description |
|--------|-------------|
| `package` | Package name from the server response |
| `version` | Package version from the server response |
| `architecture` | Package architecture from the server response |
| `filename` | Pool filename (relative path in the repository) |
| `sha256` | SHA256 checksum of the uploaded file |
| `status` | Upload status (should be `registered` on success) |

## Authentication

The action requires a bearer token for authentication. To set it up:

1. **In your debian-repo instance**, configure a CI bearer token in the service configuration (see [debian-repo documentation](https://github.com/rossigee/debian-repo)).

2. **In your GitHub repository**, add the token as a repository secret:
   - Go to **Settings → Secrets and variables → Actions**
   - Create a new secret named `DEBIAN_REPO_TOKEN` with the bearer token value

3. **In your workflow**, pass it to the action:
   ```yaml
   token: ${{ secrets.DEBIAN_REPO_TOKEN }}
   ```

The token is automatically masked in workflow logs for security.

## Gitea Actions Compatibility

This action works with **Gitea Actions** runners (which are GitHub-Actions-compatible), provided:
- The runner has network access to `github.com` and `ghcr.io` (to pull the Docker image)
- The runner has network access to your debian-repo instance

To use with Gitea Actions, reference the action the same way:
```yaml
uses: rossigee/debian-repo-upload-action@v1
```

**Note:** Gitea Actions compatibility depends on your Gitea instance version and runner setup. Test thoroughly before relying on it in production.

## Error Handling

### Upload Fails

By default, if the upload fails, the step fails and the job stops. The error message and server response are printed to the logs.

To continue on error:
```yaml
uses: rossigee/debian-repo-upload-action@v1
with:
  file: my-app.deb
  base-url: https://debs.example.com
  token: ${{ secrets.DEBIAN_REPO_TOKEN }}
  fail-on-error: false
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `file not found` | The `.deb` file path is incorrect or the build step didn't produce it | Check the `file` input and your build step |
| `HTTP 401 Unauthorized` | The bearer token is invalid or expired | Verify the `DEBIAN_REPO_TOKEN` secret in GitHub/Gitea |
| `HTTP 400 Bad Request` | The `.deb` file is malformed or missing required metadata | Ensure the file is a valid Debian package |
| `HTTP 500 Internal Server Error` | The debian-repo instance encountered an error | Check the server logs for details |

## Building and Testing

### Local Testing

```bash
# Build the Docker image
docker build -t debian-repo-upload-action .

# Run it locally (requires a real debian-repo instance)
docker run \
  -e INPUT_FILE=path/to/package.deb \
  -e INPUT_BASE_URL=https://debs.example.com \
  -e INPUT_TOKEN=your-bearer-token \
  -e INPUT_SUITE=stable \
  -e INPUT_COMPONENT=main \
  debian-repo-upload-action
```

### Testing with Actions

To test the action in a workflow before pushing to GitHub, commit it to your repository and reference it with a local path:

```yaml
- uses: ./.github/actions/debian-repo-upload  # local testing
# After confirming it works, change to:
- uses: rossigee/debian-repo-upload-action@v1  # official version
```

## Security Considerations

- **Token masking**: The bearer token is automatically masked in GitHub/Gitea logs using `::add-mask::`.
- **HTTPS only**: The action uses HTTPS (enforced by curl's default CA verification) to communicate with the debian-repo instance.
- **Constant-time comparison**: The debian-repo service uses constant-time token comparison to prevent timing attacks (see debian-repo documentation).
- **No credential storage**: The action does not store or retain the token after the upload completes.

## Troubleshooting

### "file input is required"
Check that the `file` input is set correctly:
```yaml
with:
  file: ../your-package_*.deb  # relative to the working directory
```

### "base-url input is required"
Ensure the `base-url` is set and includes the scheme (https://):
```yaml
with:
  base-url: https://debs.myorgname.com  # ✅ correct
  # NOT: debs.myorgname.com             # ❌ missing https://
```

### "HTTP 401 Unauthorized"
The token is invalid. Verify:
1. The secret is set in GitHub/Gitea: **Settings → Secrets and variables → Actions**
2. The token is correctly configured in your debian-repo instance
3. The token is being passed correctly: `token: ${{ secrets.DEBIAN_REPO_TOKEN }}`

### "curl: (60) SSL certificate problem"
The debian-repo instance has a TLS certificate issue. Ensure:
- The certificate is valid and not self-signed (or trust it via a CA bundle)
- The domain name matches the certificate CN/SAN

## License

MIT

## Contributing

Contributions welcome! Please submit issues and pull requests to [rossigee/debian-repo-upload-action](https://github.com/rossigee/debian-repo-upload-action).

## Related Projects

- [debian-repo](https://github.com/rossigee/debian-repo) — The main service this action uploads packages to
- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Gitea Actions documentation](https://docs.gitea.io/en-us/actions/)
