# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release planned

### Changed

### Fixed

### Deprecated

### Removed

### Security

## [1.0.0] - 2026-09-26

### Added
- Initial release of debian-repo-upload-action
- Docker container action for uploading .deb packages to debian-repo instances
- Support for optional distribution suites and components (defaults to server configuration)
- Secure bearer token authentication with token masking in logs
- Structured error handling with helpful error messages
- JSON response parsing with output extraction (package name, version, architecture, checksums)
- Comprehensive README with usage examples and troubleshooting guide
- CONTRIBUTING.md with development and testing instructions
- Example workflows for common use cases (simple release, matrix builds, multi-suite promotion)
- GitHub Actions workflows for linting and Docker image building/pushing
- Support for both GitHub Actions and Gitea Actions runners

### Features
- ✅ Minimal Alpine 3.23 Docker image with curl + jq
- ✅ Input validation (file existence, base URL format, required fields)
- ✅ File size validation (max 512MB, matching server limits)
- ✅ Query parameter building for optional suite/component
- ✅ HTTP error handling with response parsing (JSON and plain-text)
- ✅ Response field validation with warnings for missing fields
- ✅ Proper cleanup of temporary files with trap handling
- ✅ Cross-platform stat command compatibility (Linux/macOS)
- ✅ Defensive coding with helper functions (error, warn)

### Security
- Automatic token masking via GitHub Actions `::add-mask::`
- Constant-time token comparison at the server (debian-repo side)
- No credential storage or persistence
- HTTPS validation (curl default CA verification)

### Known Limitations
- Requires curl and jq in the container (provided via Alpine image)
- Error responses from debian-repo are currently plain-text or simple JSON (no structured error codes)
- Gitea Actions compatibility depends on runner's access to ghcr.io

---

## Unreleased Changes

### Planned
- Integration tests in the repository (test workflow against mock debian-repo)
- Support for additional output formats (YAML, environment variables)
- Better handling of partial uploads (resumable uploads if supported by server)

---

[Unreleased]: https://github.com/rossigee/debian-repo-upload-action/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rossigee/debian-repo-upload-action/releases/tag/v1.0.0
