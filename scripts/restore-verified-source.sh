#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <verified-source.tar.gz> <destination>\n' "$0" >&2
}

if [[ $# -ne 2 ]]; then
  usage
  exit 2
fi

readonly archive="$1"
readonly destination="$2"

if [[ ! -f "$archive" ]]; then
  printf 'Verified source archive does not exist: %s\n' "$archive" >&2
  exit 1
fi

if [[ -e "$destination" ]]; then
  printf 'Destination already exists: %s\n' "$destination" >&2
  exit 1
fi

mkdir "$destination"
tar -xzf "$archive" -C "$destination"
git -C "$destination" init --quiet
git -C "$destination" config user.name 'Cherry Patch Automation'
git -C "$destination" config user.email 'cherry-patch@users.noreply.github.com'
