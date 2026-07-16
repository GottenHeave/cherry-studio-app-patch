#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_ROOT

usage() {
  printf 'Usage: %s <main|v0.2>\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

case "$1" in
  main | v0.2) ;;
  *)
    usage
    exit 2
    ;;
esac

worktree="$(mktemp -d "${TMPDIR:-/tmp}/cherry-patch-check.XXXXXX")"
cleanup() {
  rm -rf "$worktree"
}
trap cleanup EXIT

"$REPOSITORY_ROOT/scripts/apply-patches.sh" "$1" "$worktree/source"
base_commit="$(git -C "$worktree/source" rev-list --max-parents=0 HEAD | tail -1)"
git -C "$worktree/source" diff --check "$base_commit"..HEAD
printf 'Patch series for %s replays without whitespace errors.\n' "$1"
