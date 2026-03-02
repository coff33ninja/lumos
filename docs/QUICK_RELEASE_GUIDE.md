<!-- lumos-docs-release: tag=v1.2.0; updated_utc=2026-03-02 -->

# Quick Release Guide

## Automatic Release (Recommended)

The entire release process is automated. Just update one file:

### 1. Update App Version

Edit `lumos_app/pubspec.yaml`:

```yaml
version: 1.2.0+1  # Change this line
```

### 2. Commit and Push

```bash
git add lumos_app/pubspec.yaml
git commit -m "chore: bump version to 1.2.0"
git push origin main
```

### 3. Everything Else is Automatic

The system automatically:
- ✓ Creates git tag (`v1.2.0` for stable, `1.2.0-beta.1` for prerelease)
- ✓ Triggers release workflow
- ✓ Builds binaries (Windows, Linux, Android)
- ✓ Generates changelog from commits
- ✓ Updates all docs metadata
- ✓ Stamps markdown files with release marker
- ✓ Commits docs changes
- ✓ Syncs GitHub Wiki
- ✓ Publishes GitHub release

**That's it!** No manual steps needed.

## Version Format

```
MAJOR.MINOR.PATCH+BUILD
```

Examples:
- `1.2.0+1` → Creates stable tag `v1.2.0`
- `1.2.0-beta.1+1` → Creates prerelease tag `1.2.0-beta.1`
- `1.2.0-rc.1+1` → Creates prerelease tag `1.2.0-rc.1`

## Manual Release (Advanced)

If you need manual control:

```powershell
# Preview changelog first
./scripts/preview-changelog.ps1 -ShowStats

# Publish release
./publish-release.ps1 -Channel stable -Tag v1.2.0 -Rebuild
```

## Emergency Agent-Only Release

If you need to release agent binaries without rebuilding the app:

```powershell
./publish-release.ps1 -Channel stable -Tag v1.2.1 -Rebuild -SkipApp
```

Or via GitHub Actions:
1. Go to Actions → `release-publish` → Run workflow
2. Set `include_apk` to `false`
3. Run

## Checking Release Status

```bash
# View latest release
gh release view --web

# Check workflow status
gh run list --workflow=release.yml --limit 5

# Check wiki sync status
gh run list --workflow=wiki-sync.yml --limit 5
```

## What Gets Updated Automatically

Every release updates:
- `docs/docs-version.json` - Release tag and date
- `docs/RELEASE_NOTES.md` - Metadata block
- `README.md` - Stable version reference
- All `*.md` files - Release marker stamp
- GitHub Wiki - Synced from `docs/wiki/`
- GitHub Release - Changelog from commits

## Troubleshooting

**Tag already exists:**
- Delete tag: `git tag -d v1.2.0 && git push origin :refs/tags/v1.2.0`
- Or increment version: `1.2.0` → `1.2.1`

**Release failed:**
- Check Actions logs: https://github.com/coff33ninja/lumos/actions
- Re-run failed workflow from Actions UI
- Or run manually: `./publish-release.ps1 -Channel stable -Tag v1.2.0 -Rebuild`

**Wiki not syncing:**
- Manually trigger: `gh workflow run wiki-sync.yml`
- Or check: https://github.com/coff33ninja/lumos/actions/workflows/wiki-sync.yml

## Best Practices

1. **Use conventional commits** for better changelogs:
   ```
   feat: add new feature
   fix: resolve bug
   docs: update documentation
   security: patch vulnerability
   ```

2. **Test before releasing:**
   ```bash
   # Run tests
   cd lumos-agent && go test ./...
   cd ../lumos_app && flutter test
   ```

3. **Preview changelog:**
   ```powershell
   ./scripts/preview-changelog.ps1 -ShowStats
   ```

4. **Update release notes** in `docs/RELEASE_NOTES.md` with user-facing highlights before bumping version

## Release Checklist

- [ ] All tests passing
- [ ] Release notes updated with highlights
- [ ] Version bumped in `pubspec.yaml`
- [ ] Commit and push to main
- [ ] Wait for automation to complete (~5-10 minutes)
- [ ] Verify release on GitHub
- [ ] Verify wiki updated
- [ ] Announce release
