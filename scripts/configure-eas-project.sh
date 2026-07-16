#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s <source-directory> <eas-project-id> <ios-bundle-id> <android-package>\n' "$0" >&2
}

if [[ $# -ne 4 || -z "$2" || -z "$3" || -z "$4" ]]; then
  usage
  exit 2
fi

readonly source_directory="$1"
readonly eas_project_id="$2"
readonly ios_bundle_identifier="$3"
readonly android_package="$4"

if [[ ! -d "$source_directory" ]]; then
  printf 'Source directory does not exist: %s\n' "$source_directory" >&2
  exit 1
fi

if [[ -f "$source_directory/app.config.ts" ]]; then
  (
    cd "$source_directory"
    IOS_BUNDLE_IDENTIFIER="$ios_bundle_identifier" ANDROID_PACKAGE="$android_package" pnpm exec tsx -e "import fs from 'node:fs'; import config from './app.config.ts'; const root = config; const expo = root.expo ?? root; if (expo.extra?.eas) delete expo.extra.eas.projectId; if (expo.updates) delete expo.updates.url; expo.ios ??= {}; delete expo.ios.appleTeamId; expo.ios.bundleIdentifier = process.env.IOS_BUNDLE_IDENTIFIER; expo.android ??= {}; expo.android.package = process.env.ANDROID_PACKAGE; fs.writeFileSync('app.json', JSON.stringify(root, null, 2) + '\\n')"
    rm app.config.ts
  )
elif [[ -f "$source_directory/app.json" ]]; then
  jq --arg ios_bundle_identifier "$ios_bundle_identifier" --arg android_package "$android_package" \
    'del(.expo.extra.eas.projectId, .expo.ios.appleTeamId, .expo.updates.url) | .expo.ios.bundleIdentifier = $ios_bundle_identifier | .expo.android.package = $android_package' \
    "$source_directory/app.json" > "$source_directory/app.json.tmp"
  mv "$source_directory/app.json.tmp" "$source_directory/app.json"
else
  printf 'No supported Expo app config found in %s.\n' "$source_directory" >&2
  exit 1
fi

if [[ -f "$source_directory/eas.json" ]]; then
  jq 'del(.submit) | if .build then .build |= map_values(if .android then .android |= del(.withoutCredentials) else . end) else . end' \
    "$source_directory/eas.json" > "$source_directory/eas.json.tmp"
  mv "$source_directory/eas.json.tmp" "$source_directory/eas.json"
fi

(
  cd "$source_directory"
  pnpm exec eas init --id "$eas_project_id" --force --non-interactive
)
