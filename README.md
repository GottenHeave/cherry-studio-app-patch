# Cherry Studio App Patch

This repository maintains replayable Clewdr integration patches for the
[`CherryHQ/cherry-studio-app`](https://github.com/CherryHQ/cherry-studio-app)
`main` and `v0.2` branches. It contains patches and automation, not a copy of
the upstream source tree.

## Patch series

| Line | Upstream branch | Patch directory | pnpm | Release tags |
| --- | --- | --- | --- | --- |
| `main` | `main` | `patches/main` | `10.26.2` | `v<upstream-version>-patch.N` |
| `v0.2` | `v0.2` | `patches/v0.2` | `11.8.0` | `v0.2-patch.N` |

Patch files are applied in bytewise filename order. Generate them as mail
patches with `git format-patch`; use a numeric prefix such as
`0001-clewdr-provider.patch` to make the order explicit.

```bash
./scripts/apply-patches.sh main /tmp/cherry-main
./scripts/check-patches.sh v0.2
```

`apply-patches.sh` creates the destination by cloning the selected upstream
branch, then replays every patch with `git am`. The destination must not
already exist. `check-patches.sh` performs the same replay in a temporary
clone and removes it afterward.

## Automation

`Patch validation` runs the two lines as independent reusable-workflow jobs.
Each job clones its upstream branch, replays the complete line, installs with
Node 24 and the pinned pnpm version, then runs focused Clewdr tests, workspace
build/check scripts, lint and format diff checks, type checking, i18n checks
when present, all tests, and Expo exports for Android and iOS.

Changes under either patch directory trigger releases for both lines. Set the
repository variable `EAS_RELEASE_ENABLED=true`, the repository variable
`EAS_PROJECT_ID`, and the repository secret `EXPO_TOKEN` to enable EAS builds.
When releases are disabled, the workflow records the reason and skips builds.
When enabled with either credential missing, the preflight job fails before
contacting EAS.

Android and iOS are built as separate EAS jobs without submission. A single
publish job waits for both builds, downloads the APK and IPA, and creates one
GitHub release for that line. The workflow removes upstream EAS project and
Apple team identifiers before binding the checkout to `EAS_PROJECT_ID` through
`scripts/configure-eas-project.sh`.
