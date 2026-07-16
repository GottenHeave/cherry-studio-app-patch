#!/usr/bin/env bash
set -euo pipefail

readonly UPSTREAM_URL="${CHERRY_UPSTREAM_URL:-https://github.com/CherryHQ/cherry-studio-app.git}"
REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPOSITORY_ROOT

usage() {
  printf 'Usage: %s <main|v0.2> <destination>\n' "$0" >&2
}

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

git clone --depth 1 --branch "$line" --single-branch "$UPSTREAM_URL" "$destination"

mapfile -d '' patches < <(
  find "$REPOSITORY_ROOT/patches/$line" -maxdepth 1 -type f -name '*.patch' -print0 |
    LC_ALL=C sort -z
)

if (( ${#patches[@]} == 0 )); then
  printf 'No patches found for %s; upstream checkout is unchanged.\n' "$line"
  exit 0
fi

git -C "$destination" am --3way "${patches[@]}"
printf 'Applied %d patch(es) for %s to %s.\n' "${#patches[@]}" "$line" "$destination"
