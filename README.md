# Cherry Studio App Patch

This repository maintains replayable Clewdr integration patches for the
[`CherryHQ/cherry-studio-app`](https://github.com/CherryHQ/cherry-studio-app)
`main` and `v0.2` branches. It contains patches and automation, not a copy of
the upstream source tree.

## Patch series

| Line | Upstream branch | Patch directory | pnpm | Release tags |
| --- | --- | --- | --- | --- |
| `main` | `main` | `patches/main` | `10.26.2` | `main-v<upstream-version>-patch.N` |
| `v0.2` | `v0.2` | `patches/v0.2` | `11.8.0` | `v0.2-patch.N` |

Patch files are applied in bytewise filename order. Generate them as mail
patches with `git format-patch`; use a numeric prefix such as
`0001-clewdr-provider.patch` to make the order explicit.

```bash
./scripts/apply-patches.sh main /tmp/cherry-main
./scripts/check-patches.sh v0.2
./scripts/check-patches.sh --allow-empty main # local bootstrap only
```

`apply-patches.sh` creates the destination from the selected upstream branch,
then replays every patch with `git am`. The destination must not already
exist. Empty patch series fail unless `--allow-empty` is passed explicitly for
local bootstrap checks. CI resolves an immutable upstream SHA and supplies it
through `--upstream-ref`. `check-patches.sh` performs the same replay in a
temporary clone and removes it afterward.

## Automation

`Patch validation` runs the two lines as independent reusable-workflow jobs.
Each line resolves one upstream commit, replays the complete series once, and
uploads the resulting verified source archive. Validation uses Node 24 and the
pinned pnpm version, then runs focused Clewdr tests, workspace build/check
scripts, lint and format diff checks, type checking, i18n checks when present,
all tests, and Expo exports for Android and iOS.

Artifact consumers restore the archive with
`scripts/restore-verified-source.sh`. It creates a local Git repository without
a remote or credentials so package lifecycle tools such as `prek install` can
install repository-local hooks without gaining network credentials.

Each patch series must provide executable
`scripts/ci/clewdr-runtime-smoke.sh`. Validation runs it in an Android emulator
and an iOS Simulator. The harness must exercise a real React Native multipart
upload and streamed response; a Node or Jest substitute does not satisfy this
gate.

Changes under either patch directory trigger releases for both lines. Release
preflight fails unless these repository-owned settings are present:

- Secret `EXPO_TOKEN`
- Variable `EAS_PROJECT_ID`
- Variable `IOS_BUNDLE_IDENTIFIER`
- Variable `ANDROID_PACKAGE`
- Variables `EAS_IOS_CREDENTIALS_READY=true` and
  `EAS_ANDROID_CREDENTIALS_READY=true`

Android and iOS are built as separate EAS jobs without submission. A single
publish job waits for both builds, downloads the APK and IPA, and creates one
GitHub release for that line. The workflow removes upstream EAS project and
Apple team identifiers, submit configuration, and unsigned Android overrides
before injecting the repository-owned application identifiers and binding the
checkout to `EAS_PROJECT_ID` through `scripts/configure-eas-project.sh`.
