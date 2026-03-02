# Lumos Release Automation Scripts

This directory contains PowerShell scripts for automating the Lumos release process.

## Changelog Generation

### generate-changelog.ps1

Generates a changelog from git commit history between two references (tags, branches, commits).

**Usage:**

```powershell
# Basic usage - commits between a tag and HEAD
./scripts/generate-changelog.ps1 -FromTag v1.0.0

# Between two specific tags
./scripts/generate-changelog.ps1 -FromTag v1.0.0 -ToRef v1.1.0

# Markdown format with grouping by commit type
./scripts/generate-changelog.ps1 -FromTag v1.0.0 -MarkdownFormat -GroupByType

# Save to file
./scripts/generate-changelog.ps1 -FromTag v1.0.0 -OutputFile CHANGELOG.md -MarkdownFormat -GroupByType
```

**Features:**

- Supports conventional commit format (feat:, fix:, docs:, etc.)
- Falls back to keyword detection for non-conventional commits
- Groups commits by type: Features, Bug Fixes, Security, Documentation, etc.
- Includes commit hash, author, date, and message
- Outputs in plain text or Markdown format

**Commit Type Detection:**

The script automatically categorizes commits based on:

1. Conventional commit prefixes:
   - `feat:` → Features
   - `fix:` → Bug Fixes
   - `docs:` → Documentation
   - `security:` → Security
   - `perf:` → Performance
   - `test:` → Tests
   - `ci:` → CI/CD
   - `build:` → Build
   - `refactor:` → Refactoring
   - `chore:` → Chores

2. Keyword detection in commit messages:
   - Security-related keywords → Security
   - Fix/bug keywords → Bug Fixes
   - Add/new/feature keywords → Features
   - Update/upgrade keywords → Updates
   - Remove/delete keywords → Removals

### preview-changelog.ps1

Preview the changelog that will be included in the next release.

**Usage:**

```powershell
# Auto-detect last tag and preview changelog
./scripts/preview-changelog.ps1

# Preview with commit statistics
./scripts/preview-changelog.ps1 -ShowStats

# Preview between specific references
./scripts/preview-changelog.ps1 -FromTag v1.0.0 -ToRef main
```

**Output includes:**

- Grouped changelog by commit type
- Optional statistics: commit count, contributor count, files changed
- Top contributors list

### update-existing-releases.ps1

Retroactively update existing GitHub releases with automatic changelogs.

**Usage:**

```powershell
# Dry run - preview changes without modifying releases
./scripts/update-existing-releases.ps1 -AllReleases -DryRun

# Update all releases (with confirmation prompt)
./scripts/update-existing-releases.ps1 -AllReleases

# Update specific releases
./scripts/update-existing-releases.ps1 -Tags v1.0.0,v1.1.0 -DryRun

# Update all releases without confirmation
./scripts/update-existing-releases.ps1 -AllReleases -Force
```

**Features:**

- Updates existing releases without recreating them
- Automatically detects previous tag for each release
- Skips releases that already have automatic changelogs
- Preserves existing release notes and appends changelog
- Dry run mode to preview changes
- Batch processing of multiple releases

**Safety:**

- Always run with `-DryRun` first to preview changes
- Requires confirmation unless `-Force` is specified
- Preserves all existing release content
- Only appends changelog, never removes content

## Release Documentation

### update-release-docs.ps1

Updates release metadata across documentation files.

**Usage:**

```powershell
./scripts/update-release-docs.ps1 -Tag v1.1.0 -Channel stable
```

**Updates:**

- `docs/docs-version.json` - Release tag and date
- `docs/RELEASE_NOTES.md` - Metadata block
- `docs/wiki/Releases-and-Versioning.md` - Stable version reference
- `README.md` - Current stable release tag
- Stamps all Markdown files with release marker comment

## Validation Scripts

### validate-version-policy.ps1

Validates version policy compliance.

### validate-release-compatibility.ps1

Validates app/agent version compatibility matrix.

### validate-docs-version.ps1

Validates documentation version metadata matches release tag.

### validate-release-metadata.ps1

Validates release notes metadata and checklist completion.

### validate-apk-signing.ps1

Validates Android APK signing certificate continuity.

## Release Workflow

The complete release process integrates these scripts:

1. **Prepare release:**
   ```powershell
   ./scripts/preview-changelog.ps1 -ShowStats
   ```

2. **Update documentation:**
   ```powershell
   ./scripts/update-release-docs.ps1 -Tag v1.1.0 -Channel stable
   ```

3. **Validate:**
   ```powershell
   ./scripts/validate-version-policy.ps1
   ./scripts/validate-release-compatibility.ps1
   ./scripts/validate-docs-version.ps1 -ExpectedTag v1.1.0 -Channel stable
   ```

4. **Publish:**
   ```powershell
   ./publish-release.ps1 -Channel stable -Tag v1.1.0 -Rebuild
   ```

The changelog is automatically generated and included in the GitHub release notes.

## Automatic Changelog in Releases

When `publish-release.ps1` runs, it automatically:

1. Detects the previous release tag
2. Generates a changelog of all commits since that tag
3. Groups commits by type (Features, Bug Fixes, Security, etc.)
4. Appends the changelog to the release notes
5. Includes the compatibility matrix

This ensures every release has complete traceability of all changes.

## CI/CD Integration

These scripts are integrated into `.github/workflows/release.yml`:

- Automatic documentation updates on release
- Validation gates before publishing
- Changelog generation for every release
- APK signing validation
- Compatibility matrix enforcement

## Best Practices

1. **Use conventional commits** for better automatic categorization:
   ```
   feat: add new power control API
   fix: resolve token expiration issue
   docs: update installation guide
   security: patch authentication vulnerability
   ```

2. **Preview before releasing:**
   ```powershell
   ./scripts/preview-changelog.ps1 -ShowStats
   ```

3. **Keep release notes focused** on user-facing changes; the automatic changelog provides complete commit history.

4. **Validate before pushing:**
   ```powershell
   ./scripts/release-doctor.ps1 -ExpectedTag v1.1.0 -Rebuild
   ```

## Updating Existing Releases

To add automatic changelogs to releases that were published before this feature was implemented:

1. **Preview changes first:**
   ```powershell
   ./scripts/update-existing-releases.ps1 -AllReleases -DryRun
   ```

2. **Review the output** to ensure changelogs look correct

3. **Apply updates:**
   ```powershell
   ./scripts/update-existing-releases.ps1 -AllReleases
   ```

4. **Update specific releases only:**
   ```powershell
   ./scripts/update-existing-releases.ps1 -Tags v1.0.0,v1.1.0
   ```

The script will:
- Preserve all existing release notes
- Append automatic changelog after a separator
- Skip releases that already have changelogs
- Show progress and summary statistics
