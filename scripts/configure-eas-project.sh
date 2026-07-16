#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <source-directory> <eas-project-id>\n' "$0" >&2
}

if [[ $# -ne 2 || -z "$2" ]]; then
  usage
  exit 2
fi

readonly source_directory="$1"
readonly eas_project_id="$2"

if [[ ! -d "$source_directory" ]]; then
  printf 'Source directory does not exist: %s\n' "$source_directory" >&2
  exit 1
fi

if [[ -f "$source_directory/app.config.ts" ]]; then
  (
    cd "$source_directory"
    pnpm exec tsx -e "import fs from 'node:fs'; import config from './app.config.ts'; const root = config; const expo = root.expo ?? root; if (expo.extra?.eas) delete expo.extra.eas.projectId; if (expo.ios) delete expo.ios.appleTeamId; if (expo.updates) delete expo.updates.url; fs.writeFileSync('app.json', JSON.stringify(root, null, 2) + '\\n')"
    rm app.config.ts
  )
elif [[ -f "$source_directory/app.json" ]]; then
  jq 'del(.expo.extra.eas.projectId, .expo.ios.appleTeamId, .expo.updates.url)' \
    "$source_directory/app.json" > "$source_directory/app.json.tmp"
  mv "$source_directory/app.json.tmp" "$source_directory/app.json"
else
  printf 'No supported Expo app config found in %s.\n' "$source_directory" >&2
  exit 1
fi

(
  cd "$source_directory"
  pnpm exec eas init --id "$eas_project_id" --force --non-interactive
)
