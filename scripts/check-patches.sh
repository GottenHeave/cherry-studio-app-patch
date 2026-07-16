#!/usr/bin/env bash
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_ROOT

usage() {
  printf 'Usage: %s [--allow-empty] [--upstream-ref SHA] <main|v0.2>\n' "$0" >&2
}

apply_options=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-empty)
      apply_options+=("$1")
      shift
      ;;
    --upstream-ref)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      apply_options+=("$1" "$2")
      shift 2
      ;;
    --) shift; break ;;
    -*) usage; exit 2 ;;
    *) break ;;
  esac
done

[[ $# -eq 1 ]] || { usage; exit 2; }
readonly line="$1"

case "$line" in
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

"$REPOSITORY_ROOT/scripts/apply-patches.sh" "${apply_options[@]}" "$line" "$worktree/source"
base_commit="$(git -C "$worktree/source" rev-list --max-parents=0 HEAD | tail -1)"
git -C "$worktree/source" diff --check "$base_commit"..HEAD
printf 'Patch series for %s replays without whitespace errors.\n' "$line"
