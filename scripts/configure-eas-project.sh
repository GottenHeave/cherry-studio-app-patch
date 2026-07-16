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

raw_dynamic_config="$(mktemp "$source_directory/.raw-app-config.XXXXXX")"
evaluated_config="$(mktemp "$source_directory/.evaluated-app-config.XXXXXX")"
sanitized_config="$(mktemp "$source_directory/.sanitized-app-config.XXXXXX")"
cleanup_config_files() {
  rm -f "$raw_dynamic_config" "$evaluated_config" "$sanitized_config"
}
trap cleanup_config_files EXIT

if [[ -f "$source_directory/app.config.ts" ]]; then
  (
    cd "$source_directory"
    EXPO_NO_DOTENV=1 EXPO_NO_CLIENT_ENV_VARS=1 pnpm exec expo config --full --json
  ) > "$raw_dynamic_config"
  if ! jq -e . "$raw_dynamic_config" >/dev/null 2>&1; then
    first_line_length="$(head -n 1 "$raw_dynamic_config" | wc -c | tr -d ' ')"
    first_line_sha256="$(head -n 1 "$raw_dynamic_config" | sha256sum | cut -d ' ' -f 1)"
    printf 'Expo config output is not JSON; first line length=%s sha256=%s (content redacted).\n' \
      "$first_line_length" "$first_line_sha256" >&2
    exit 1
  fi
  jq -e '
    .exp
    | select(type == "object" and (.name | type == "string" and length > 0) and (.slug | type == "string" and length > 0))
    | { expo: . }
  ' "$raw_dynamic_config" > "$evaluated_config"
elif [[ -f "$source_directory/app.json" ]]; then
  jq -e 'select(.expo | type == "object")' "$source_directory/app.json" > "$evaluated_config"
else
  printf 'No supported Expo app config found in %s.\n' "$source_directory" >&2
  exit 1
fi

jq --arg ios_bundle_identifier "$ios_bundle_identifier" --arg android_package "$android_package" '
  del(.expo._internal, .expo.extra.eas.projectId, .expo.ios.appleTeamId, .expo.updates.url)
  | .expo.ios = (.expo.ios // {})
  | .expo.ios.bundleIdentifier = $ios_bundle_identifier
  | .expo.android = (.expo.android // {})
  | .expo.android.package = $android_package
' "$evaluated_config" > "$sanitized_config"
jq -e '
  type == "object"
  and (.expo | type == "object")
  and (.expo.name | type == "string" and length > 0)
  and (.expo.slug | type == "string" and length > 0)
  and (.expo.ios.bundleIdentifier | type == "string" and length > 0)
  and (.expo.android.package | type == "string" and length > 0)
' "$sanitized_config" >/dev/null

mv "$sanitized_config" "$source_directory/app.json"
if [[ -f "$source_directory/app.config.ts" ]]; then
  rm "$source_directory/app.config.ts"
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
