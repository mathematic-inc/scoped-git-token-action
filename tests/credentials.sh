#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

server=${TEST_SERVER_URL:-$GITHUB_SERVER_URL}
repositories=(mathematic-inc/scoped-git-token-action mathematic-inc/another_repo.test)

assert_absent() {
  local response
  if response=$(printf 'url=%s\n\n' "$1" | env -u GIT_CONFIG_GLOBAL git credential fill 2>&1); then
    fail 'Git returned a credential for an unnamed repository.'
  fi
  [[ $response != *'password='* ]] || fail 'Git returned a password on failure.'
  [[ $response == *'terminal prompts disabled'* ]] || fail 'Git did not disable its prompt.'
}

case $1 in
  present)
    [[ ${GIT_TERMINAL_PROMPT:-} == 0 ]] || fail 'Git can prompt for a credential.'
    [[ $(env -u GIT_CONFIG_GLOBAL git config --get test.preserved) == present ]] || fail 'Git lost the prior config entry.'
    for repository in "${repositories[@]}"; do
      for suffix in '' .git; do
        url=$server/$repository$suffix
        response=$(printf 'url=%s\n\n' "$url" | env -u GIT_CONFIG_GLOBAL git credential fill)
        response=${response//$'\r'/}
        [[ $'\n'$response$'\n' == *$'\nusername=x-access-token\n'* ]] || fail 'Git returned the wrong username.'
        [[ $'\n'$response$'\n' == *$'\npassword='"$TEST_TOKEN"$'\n'* ]] || fail 'Git returned the wrong token.'
        [[ $'\n'$response$'\n' == *$'\npath='"$repository$suffix"$'\n'* ]] || fail 'Git lost the repository path.'
        printf 'PASS credential: %s\n' "$url"

        trace=$(printf 'url=%s\n\n' "$url" | GIT_TRACE=1 env -u GIT_CONFIG_GLOBAL git credential fill 2>&1 >/dev/null)
        [[ $trace == *trace:* ]] || fail 'Git produced no trace.'
        [[ $trace != *"$TEST_TOKEN"* ]] || fail 'Git trace contains the token.'
      done
    done
    for suffix in '' .git; do
      assert_absent "$server/mathematic-inc/other$suffix"
      assert_absent "$server/mathematic-inc/scoped-git-token-action-extra$suffix"
    done
    assert_absent 'https://other.example/mathematic-inc/scoped-git-token-action'
    for ((index = 0; index < GIT_CONFIG_COUNT; index++)); do
      key=GIT_CONFIG_VALUE_$index
      [[ ${!key} != *"$TEST_TOKEN"* ]] || fail 'Git config contains the token.'
    done
    printf 'PASS scope, prior config, prompt policy, and trace\n'
    ;;
  absent)
    [[ -z ${SCOPED_GIT_TOKEN+x} ]] || fail 'The next step has the token variable.'
    [[ ${GIT_CONFIG_COUNT:-} == 2 ]] || fail 'The next step has extra config entries.'
    export GIT_TERMINAL_PROMPT=0
    for repository in "${repositories[@]}"; do
      for suffix in '' .git; do
        assert_absent "$server/$repository$suffix"
      done
    done
    printf 'PASS next step has no credential\n'
    ;;
  *) fail 'Unknown credential test.' ;;
esac
