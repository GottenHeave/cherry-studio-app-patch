#!/usr/bin/env bash
set -euo pipefail

readonly UPSTREAM_URL="${CHERRY_UPSTREAM_URL:-https://github.com/CherryHQ/cherry-studio-app.git}"
REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_ROOT

usage() {
  printf 'Usage: %s [--allow-empty] [--upstream-ref SHA] <main|v0.2> <destination>\n' "$0" >&2
}

allow_empty=false
upstream_ref=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-empty)
      allow_empty=true
      shift
      ;;
    --upstream-ref)
      [[ $# -ge 2 ]] || { usage; exit 2; }
      upstream_ref="$2"
      shift 2
      ;;
    --) shift; break ;;
    -*) usage; exit 2 ;;
    *) break ;;
  esac
done

if [[ $# -ne 2 ]]; then
  usage
  exit 2
fi

readonly line="$1"
readonly destination="$2"

case "$line" in
  main | v0.2) ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ -e "$destination" ]]; then
  printf 'Destination already exists: %s\n' "$destination" >&2
  exit 1
fi

if [[ -n "$upstream_ref" ]]; then
  [[ "$upstream_ref" =~ ^[0-9a-f]{40}$ ]] || {
    printf 'Upstream ref must be a full 40-character commit SHA.\n' >&2
    exit 2
  }
  git init --quiet "$destination"
  git -C "$destination" remote add origin "$UPSTREAM_URL"
  git -C "$destination" fetch --quiet --depth 1 origin "$upstream_ref"
  resolved_ref="$(git -C "$destination" rev-parse FETCH_HEAD)"
  if [[ "$resolved_ref" != "$upstream_ref" ]]; then
    printf 'Resolved upstream ref %s does not match requested %s.\n' "$resolved_ref" "$upstream_ref" >&2
    exit 1
  fi
  git -C "$destination" checkout --quiet --detach "$resolved_ref"
else
  git clone --depth 1 --branch "$line" --single-branch "$UPSTREAM_URL" "$destination"
fi

mapfile -d '' patches < <(
  find "$REPOSITORY_ROOT/patches/$line" -maxdepth 1 -type f -name '*.patch' -print0 |
    LC_ALL=C sort -z
)

if (( ${#patches[@]} == 0 )); then
  if [[ "$allow_empty" == true ]]; then
    printf 'No patches found for %s; explicit bootstrap mode leaves upstream unchanged.\n' "$line"
    exit 0
  fi
  printf 'No patches found for %s. Pass --allow-empty only for local bootstrap checks.\n' "$line" >&2
  exit 1
fi

committer_name="$(git -C "$destination" config user.name || printf 'Cherry Patch Automation')"
committer_email="$(git -C "$destination" config user.email || printf 'cherry-patch@users.noreply.github.com')"
GIT_COMMITTER_NAME="$committer_name" GIT_COMMITTER_EMAIL="$committer_email" \
  git -C "$destination" am --3way "${patches[@]}"
printf 'Applied %d patch(es) for %s to %s.\n' "${#patches[@]}" "$line" "$destination"
