# Usage Examples

Real-world examples of using the debian-repo-upload-action in your workflows. Copy and adapt these to your projects.

## Example 1: Simple Release Upload

**File:** `.github/workflows/release.yaml`

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Debian package
        run: |
          # Your build commands here
          dpkg-buildpackage -us -uc

      - name: Upload to debian-repo
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main
```

## Example 2: Matrix Build (Multiple Architectures)

Build and upload the same package for multiple architectures (e.g., amd64, arm64).

**File:** `.github/workflows/release.yaml`

```yaml
name: Build and Release (Multi-Arch)

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        arch: [amd64, arm64]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Debian package (${{ matrix.arch }})
        run: |
          # Cross-compile or use native build
          dpkg-buildpackage -a${{ matrix.arch }} -us -uc

      - name: Upload to debian-repo
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*_${{ matrix.arch }}.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main
```

## Example 3: Conditional Uploads (Branch-Based)

Upload to different suites based on the git ref (e.g., `testing` for develop, `stable` for tags).

**File:** `.github/workflows/ci.yaml`

```yaml
name: CI with Conditional Upload

on:
  push:
    branches:
      - main
      - develop
    tags:
      - 'v*'
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Debian package
        run: dpkg-buildpackage -us -uc

      - name: Upload to stable (releases only)
        if: startsWith(github.ref, 'refs/tags/v')
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main

      - name: Upload to testing (develop branch)
        if: github.ref == 'refs/heads/develop'
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: testing
          component: main
```

## Example 4: Using Action Outputs

Capture the action's outputs (package name, version, checksums) and use them to create a GitHub Release.

**File:** `.github/workflows/release.yaml`

```yaml
name: Build, Upload, and Create Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Debian package
        run: dpkg-buildpackage -us -uc

      - name: Upload to debian-repo
        id: upload
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main

      - name: Create GitHub Release
        uses: ncipollo/release-action@v1
        with:
          tag: ${{ github.ref }}
          body: |
            **Debian Repository Upload Summary**
            - **Package**: ${{ steps.upload.outputs.package }}
            - **Version**: ${{ steps.upload.outputs.version }}
            - **Architecture**: ${{ steps.upload.outputs.architecture }}
            - **Location**: ${{ steps.upload.outputs.filename }}
            - **SHA256**: `${{ steps.upload.outputs.sha256 }}`
```

## Example 5: Multi-Suite Promotion

Upload to `unstable` for early testing, then promote to `testing` and `stable` after review.

**File:** `.github/workflows/release.yaml`

```yaml
name: Build and Promote Through Suites

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Debian package
        run: dpkg-buildpackage -us -uc

      - name: Upload to unstable (for early testing)
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: unstable
          component: main

      - name: Request approval
        run: |
          echo "Package uploaded to unstable suite"
          echo "Review at: https://debs.example.com/"
          # You can use GitHub Environments with deployment protection rules here

      - name: Promote to testing
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: testing
          component: main

      - name: Promote to stable
        uses: rossigee/debian-repo-upload-action@v1
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main
```

## Example 6: Error Handling (Continue on Failure)

Allow the workflow to continue even if the upload fails (useful for non-critical uploads).

**File:** `.github/workflows/ci.yaml`

```yaml
name: Upload with Error Handling

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Debian package
        run: dpkg-buildpackage -us -uc

      - name: Try to upload (continue on error)
        uses: rossigee/debian-repo-upload-action@v1
        continue-on-error: true
        with:
          file: ../my-package_*.deb
          base-url: https://debs.example.com
          token: ${{ secrets.DEBIAN_REPO_TOKEN }}
          suite: stable
          component: main
          fail-on-error: false

      - name: Send notification on failure
        if: failure()
        run: |
          # Send to Slack, email, create an issue, etc.
          echo "⚠️ Package upload failed, but continuing..."
```

## Setup Checklist

For each example, ensure you have:

1. **Secret configured**: Add `DEBIAN_REPO_TOKEN` to your repository secrets (Settings → Secrets and variables → Actions)
2. **Build step working**: Your `dpkg-buildpackage` or equivalent must produce a `.deb` file
3. **debian-repo instance accessible**: The `base-url` must be reachable from GitHub Actions runners
4. **File path correct**: Adjust `../my-package_*.deb` to match your actual build output

## Troubleshooting

- **Action not found**: Make sure you're using `rossigee/debian-repo-upload-action@v1` (not a local path)
- **Token 401 errors**: Verify the `DEBIAN_REPO_TOKEN` secret is set and contains a valid bearer token
- **File not found**: Check that the build step actually creates a `.deb` file at the path you specify
- **Build fails after upload**: Uploads are separate from the build job; if the action fails, it won't affect your build artifacts
