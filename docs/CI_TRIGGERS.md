<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# CI/CD Workflow Triggers

This document explains what triggers each workflow and how to avoid unnecessary builds.

## Workflows Overview

| Workflow | Triggers | Skips On |
|----------|----------|----------|
| `ci-validate` | Code changes on main/PR | Docs, markdown, wiki scripts, `[skip ci]` |
| `codeql` | Code changes, weekly schedule | Docs, markdown, wiki/validation scripts |
| `release-publish` | Tag push, manual dispatch | Never (intentional) |
| `wiki-sync` | Wiki docs changes, releases | Never (lightweight) |
| `version-bump-tag` | `pubspec.yaml` version change | Never (creates tags) |

## CI Validation (`ci-validate`)

**Runs on:**
- Push to `main` branch
- Pull requests to `main`

**Skips when:**
- Only `docs/**` files changed
- Only `*.md` files changed
- Only wiki sync files changed
- Commit message contains `[skip ci]` or `[ci skip]`

**What it does:**
- Validates version policy
- Runs Go tests and vet
- Runs Flutter analyze and tests

**Example commits that skip CI:**
```bash
git commit -m "docs: update README [skip ci]"
git commit -m "docs(release): auto-update metadata for v1.2.0 [skip ci]"
```

## CodeQL Security Scanning (`codeql`)

**Runs on:**
- Push to `main` branch
- Pull requests to `main`
- Weekly schedule (Tuesday 13:18 UTC)

**Skips when:**
- Only `docs/**` files changed
- Only `*.md` files changed
- Only wiki/validation/generation scripts changed

**What it does:**
- Scans Go code for security issues
- Scans Java/Kotlin (Android) code
- Scans GitHub Actions workflows

**Note:** Scheduled runs always execute (weekly security scan).

## Release Publishing (`release-publish`)

**Runs on:**
- Tag push matching `v*` or semver pattern
- Manual workflow dispatch

**Never skips** - releases are intentional actions.

**What it does:**
- Builds all binaries
- Generates changelog
- Updates docs metadata
- Publishes GitHub release
- Commits docs changes with `[skip ci]`
- Triggers wiki sync

## Wiki Sync (`wiki-sync`)

**Runs on:**
- Changes to `docs/wiki/**`
- Changes to `docs/*.md`
- Release published/edited
- Manual workflow dispatch

**Never skips** - wiki sync is lightweight and fast.

**What it does:**
- Syncs `docs/wiki/` to GitHub Wiki
- Updates wiki pages

## Version Bump Tag (`version-bump-tag`)

**Runs on:**
- Changes to `lumos_app/pubspec.yaml` on `main`

**Never skips** - version changes should create tags.

**What it does:**
- Reads version from `pubspec.yaml`
- Creates git tag (`v1.2.0` for stable, `1.2.0-beta.1` for prerelease)
- Pushes tag (triggers release workflow)

## How to Skip CI

### Method 1: Commit Message

Add `[skip ci]` or `[ci skip]` to your commit message:

```bash
git commit -m "docs: update documentation [skip ci]"
git commit -m "chore: fix typo [ci skip]"
```

### Method 2: Only Change Ignored Paths

Changes to these paths automatically skip CI:
- `docs/**` - All documentation
- `*.md` - Markdown files in root
- `.github/workflows/wiki-sync.yml` - Wiki workflow
- `scripts/publish-wiki.ps1` - Wiki script
- `scripts/generate-*.ps1` - Generation scripts
- `scripts/update-*.ps1` - Update scripts
- `scripts/validate-*.ps1` - Validation scripts

### Method 3: Docs-Only Commits

The release automation automatically adds `[skip ci]` when committing docs:

```bash
git commit -m "docs(release): auto-update metadata for v1.2.0 [skip ci]"
```

## When CI Runs

### Always Runs:
- Code changes in `lumos-agent/` or `lumos_app/`
- Changes to `.github/workflows/ci.yml` or `.github/workflows/codeql.yml`
- Changes to `publish-release.ps1` or `rebuild-all.ps1`
- Pull requests (unless only docs changed)

### Never Runs:
- Docs-only changes
- Wiki-only changes
- Commits with `[skip ci]`

### Scheduled Runs:
- CodeQL: Every Tuesday at 13:18 UTC (security scan)

## Optimization Tips

1. **Batch docs changes** - Make multiple doc updates in one commit to avoid multiple wiki syncs

2. **Use `[skip ci]` for non-code changes:**
   ```bash
   git commit -m "docs: update guide [skip ci]"
   git commit -m "chore: update .gitignore [skip ci]"
   ```

3. **Separate code and docs commits** - Keep code changes and doc updates in separate commits

4. **Let automation handle docs** - Release workflow automatically updates docs with `[skip ci]`

## Workflow Dependencies

```
pubspec.yaml change
    ↓
version-bump-tag (creates tag)
    ↓
release-publish (builds & publishes)
    ↓
├─ Commits docs with [skip ci]
└─ Triggers wiki-sync
```

## Troubleshooting

**CI running on docs-only changes:**
- Check if commit message has `[skip ci]`
- Verify only ignored paths were changed
- Check workflow logs for trigger reason

**CodeQL running too often:**
- It's scheduled weekly for security
- Skips on docs-only changes
- Can be disabled in workflow file if needed

**Wiki not syncing:**
- Check if `docs/wiki/**` was actually changed
- Manually trigger: `gh workflow run wiki-sync.yml`
- Check workflow logs

## Summary

**To avoid unnecessary builds:**
1. Add `[skip ci]` to docs/chore commits
2. Keep docs changes separate from code changes
3. Let automation handle release docs (already has `[skip ci]`)

**Workflows are optimized to:**
- Skip CI on docs-only changes
- Skip CodeQL on non-code changes
- Auto-skip on `[skip ci]` commits
- Run security scans weekly regardless
