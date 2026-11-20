#!/usr/bin/env bash
set -euo pipefail

: "${SCOPED_GIT_TOKEN:?Input token is required.}"
mask=${SCOPED_GIT_TOKEN//%/%25}
mask=${mask//$'\r'/%0D}
mask=${mask//$'\n'/%0A}
printf '::add-mask::%s\n' "$mask"

: "${SCOPED_GIT_RUN:?Input run is required.}"

GIT_CONFIG_COUNT=${GIT_CONFIG_COUNT:-0}

add_config() {
  export "GIT_CONFIG_KEY_$GIT_CONFIG_COUNT=$1"
  export "GIT_CONFIG_VALUE_$GIT_CONFIG_COUNT=$2"
  GIT_CONFIG_COUNT=$((GIT_CONFIG_COUNT + 1))
}

repository_count=0
while IFS= read -r repository; do
  repository=${repository#"${repository%%[![:space:]]*}"}
  repository=${repository%"${repository##*[![:space:]]}"}
  [[ -n $repository ]] || continue
  if [[ ! $repository =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ||
    ${repository#*/} == . || ${repository#*/} == .. ]]; then
    printf "Invalid repository name '%s'. Use owner/name.\n" "${repository//[[:cntrl:]]/?}" >&2
    exit 1
  fi
  for suffix in '' .git; do
    url=${GITHUB_SERVER_URL%/}/$repository$suffix
    add_config "credential.$url.helper" ''
    # shellcheck disable=SC2016 # The helper reads SCOPED_GIT_TOKEN from the environment when Git calls it, so GIT_TRACE does not show the token.
    add_config "credential.$url.helper" '!f() { if [ "$1" = get ]; then printf "%s\n" username=x-access-token "password=$SCOPED_GIT_TOKEN"; fi; }; f'
    add_config "credential.$url.useHttpPath" true
  done
  repository_count=$((repository_count + 1))
done <<<"${SCOPED_GIT_REPOSITORIES:-}"

if [[ $repository_count == 0 ]]; then
  printf "Input 'repositories' must contain at least one owner/name.\n" >&2
  exit 1
fi

export GIT_CONFIG_COUNT GIT_TERMINAL_PROMPT=0
exec bash --noprofile --norc -e -o pipefail -c "$SCOPED_GIT_RUN"
