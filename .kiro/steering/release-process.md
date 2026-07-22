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

## Commit message conventions

Use [Conventional Commits](https://www.conventionalcommits.org/) for all commits:

- `feat:` — New feature (bumps minor)
- `fix:` — Bug fix (bumps patch)
- `docs:` — Documentation only
- `chore:` — Maintenance (deps, CI, steering)
- `refactor:` — Code change that neither fixes a bug nor adds a feature

The subject line (first line) should be ≤70 characters. Use the body for details.
These messages are auto-extracted into GitHub Release notes by the CI workflow.

## Release checklist (MUST follow in order)

1. **Update README.md** if the release adds/changes user-facing features.
2. **Bump version** in all 3 places listed above.
3. **`make build`** — verify compilation passes.
4. **Commit** with a descriptive conventional-commit message.
5. **Tag**: `git tag -a vX.Y.Z -m "vX.Y.Z: short description"`
6. **Push**: `git push origin main --tags`
7. **Verify CI**: `gh run watch <run-id> --exit-status`
8. **Verify Release**: `gh release view vX.Y.Z` — confirm release notes are correct.

## Release notes (auto-generated)

The GitHub Action generates release notes from git log between the previous tag
and the new tag. Format:

```
## KiroMeter vX.Y.Z

### What's Changed
- feat: description of feature
- fix: description of fix

**Full Changelog**: compare link

---

### Installation
...
### Prerequisites
...
```

Because release notes are auto-generated from commit messages, **write good commit
messages** — they are user-facing documentation.

## Release flow

Releases are cut by pushing a `vX.Y.Z` tag. The `Build & Release` GitHub Action
(`.github/workflows/release.yml`) builds the `.app`, zips it as
`KiroMeter-macOS.zip`, and publishes a GitHub Release with auto-generated notes.

## Branch policy

- All work happens on `main` for now (single developer).
- If a feature is risky or multi-session, use a feature branch (`feat/name`)
  and merge via PR before tagging.
- Never push a tag on a branch other than `main`.
- Always `git fetch origin && git rebase origin/main` before tagging to ensure
  local main matches remote.

## Safety rules for AI agents

AI agents (Kiro, Claude, etc.) working on this repo MUST:

1. **Never push a tag without running `make build` first** — a broken release
   cannot be un-published (users may have already downloaded it).
2. **Never skip the README update** for user-facing changes — users read the
   README to decide whether to upgrade.
3. **Always verify the CI run completes** before declaring a release done.
4. **Never reuse a version number** — always bump, even for tiny fixes.
5. **Always include the `xattr -cr` instruction** in release notes — users
   will hit Gatekeeper otherwise.
6. **Commit messages must be meaningful** — they become release notes.
7. **Do not amend or force-push** published tags — ship a new patch version.

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
- **`.help()` tooltips in NSPopover are unreliable** — use inline text instead.
