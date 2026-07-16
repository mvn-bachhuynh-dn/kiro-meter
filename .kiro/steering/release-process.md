# Release & Versioning

## Version is a single source of truth

`AppInfo.version` (Sources/KiroMeter/App/AppInfo.swift) is the ONE runtime source
of version. It reads `CFBundleShortVersionString` from the bundle's Info.plist,
falling back to `AppInfo.devFallbackVersion` only for `swift run` (no bundle).

Never hardcode a version in views. About screen, popover footer, and
`UpdateChecker` all read from `AppInfo`. A past bug was version drift between
the About screen and the menu bar because versions were hardcoded in 3+ places.

## Bumping the version — change ALL THREE, keep them in sync

1. `Sources/KiroMeter/App/AppInfo.swift` → `devFallbackVersion`
2. `scripts/bundle.sh` → `CFBundleShortVersionString`
3. `.github/workflows/release.yml` → `CFBundleShortVersionString`

Follow semver. Any user-facing fix/feature gets a bump. Do not reuse a version
that was already published as a GitHub Release.

## Release flow

Releases are cut by pushing a `vX.Y.Z` tag. The `Build & Release` GitHub Action
(`.github/workflows/release.yml`) builds the `.app`, zips it as
`KiroMeter-macOS.zip`, and publishes a GitHub Release.

Typical sequence:
1. Bump the three version references, `make build` to verify.
2. Commit, then `git tag -a vX.Y.Z -m "..."`, then `git push origin main --tags`.

## Gotchas learned

- **Never re-tag a published release.** If `vX.Y.0` is already published, ship
  fixes as `vX.Y.1` (semver patch), not a force-moved tag.
- **Rebase can orphan a freshly-created tag.** If `git push` is rejected because
  remote `main` advanced, and you `git rebase origin/main`, your commit hash
  changes but the tag still points at the pre-rebase (now-dangling) commit.
  After rebasing, delete and recreate the tag on the new HEAD, then
  `git push origin vX.Y.Z --force` (tag only).
- Verify a tag's target commit with `git rev-parse vX.Y.Z^{}` (the `^{}`
  dereferences the annotated tag object to the commit).
- The README screenshot / edits may be made directly on GitHub web — always
  `git fetch` and rebase rather than assuming local `main` is current.
