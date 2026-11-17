#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script=${TEST_ACTION_SCRIPT:-$root/scoped-git-token.sh}
cd "$root/tests"
export GIT_CONFIG_NOSYSTEM=1 GIT_ASKPASS='' SSH_ASKPASS='' GCM_INTERACTIVE=never
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=test.preserved GIT_CONFIG_VALUE_0=present
export GIT_CONFIG_KEY_1=credential.helper GIT_CONFIG_VALUE_1=
export SCOPED_GIT_TOKEN='test-token-%-only' TEST_TOKEN='test-token-%-only'
export SCOPED_GIT_SERVER_URL=https://github.example.test
export TEST_SERVER_URL=$SCOPED_GIT_SERVER_URL
export SCOPED_GIT_REPOSITORIES=$'  mathematic-inc/scoped-git-token-action \r\n\n\tmathematic-inc/another_repo.test\t'
export SCOPED_GIT_DIRECTORY=$root
export SCOPED_GIT_RUN='bash tests/credentials.sh present'

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

assert_exit() {
  local expected=$1
  local status=0
  output=$(bash "$script" 2>&1) || status=$?
  [[ $status == "$expected" ]] || fail "Expected exit $expected; got $status."
}

bash "$script"
unset SCOPED_GIT_TOKEN
bash "$root/tests/credentials.sh" absent
export SCOPED_GIT_TOKEN=$TEST_TOKEN

for repository in 'missing-slash' 'owner/repo/extra' 'owner/re po' 'owner_1/repo' 'owner/repo*' 'owner/.' 'owner/..' '/repo' 'owner/'; do
  SCOPED_GIT_REPOSITORIES=$repository SCOPED_GIT_RUN='exit 99' assert_exit 1
  [[ $output == *"Invalid repository name '$repository'; use owner/name." ]] || fail 'The repository error lacks its sentence.'
done
SCOPED_GIT_REPOSITORIES=$' \n\t\r' assert_exit 1
SCOPED_GIT_TOKEN='' assert_exit 1
SCOPED_GIT_RUN='' assert_exit 1
GIT_CONFIG_COUNT=invalid assert_exit 1
printf 'PASS invalid and absent inputs\n'

SCOPED_GIT_RUN='exit 37' assert_exit 37
SCOPED_GIT_RUN=$'false\nexit 99' assert_exit 1
SCOPED_GIT_RUN=$'false | true\nexit 99' assert_exit 1
# shellcheck disable=SC2016 # The child Bash process must expand this command.
SCOPED_GIT_RUN='[[ -f action.yml ]] && [[ -z $unset_input ]]' assert_exit 0
[[ $output == '::add-mask::test-token-%25-only' ]] || fail 'The action did not mask the token.'
printf 'PASS exit code, Bash flags, directory, and mask\n'

export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_2=credential.$SCOPED_GIT_SERVER_URL/mathematic-inc/scoped-git-token-action.helper
export GIT_CONFIG_KEY_3=credential.$SCOPED_GIT_SERVER_URL/mathematic-inc/scoped-git-token-action.git.helper
export GIT_CONFIG_VALUE_2='!f() { printf "%s\n" username=lower password=lower; }; f'
export GIT_CONFIG_VALUE_3=$GIT_CONFIG_VALUE_2
bash "$script"
printf 'PASS lower helper reset for both URL forms\n'

# shellcheck disable=SC2016 # The child Bash process must expand these commands.
export SCOPED_GIT_RUN='
  export SCOPED_GIT_TOKEN=changed-test-token TEST_TOKEN=changed-test-token
  bash tests/credentials.sh present
  for suffix in "" .git; do
    helper=$(env -u GIT_CONFIG_GLOBAL git config --get "credential.$TEST_SERVER_URL/mathematic-inc/scoped-git-token-action$suffix.helper")
    for operation in store erase unknown; do
      response=$(bash --noprofile --norc -c "${helper#!} $operation" </dev/null)
      [[ -z $response ]] || exit 1
    done
  done
'
bash "$script"
printf 'PASS token read at helper call and get-only response\n'
