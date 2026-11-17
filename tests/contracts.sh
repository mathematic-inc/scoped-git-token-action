#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script=$root/scoped-git-token.sh
cd "$root"
export GIT_CONFIG_NOSYSTEM=1 GIT_ASKPASS='' SSH_ASKPASS=''
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0=test.preserved GIT_CONFIG_VALUE_0=present
export GIT_CONFIG_KEY_1=credential.helper GIT_CONFIG_VALUE_1=
export SCOPED_GIT_TOKEN='test-token-%-only' TEST_TOKEN='test-token-%-only'
export GITHUB_SERVER_URL=https://github.example.test
export SCOPED_GIT_REPOSITORIES=$'  mathematic-inc/scoped-git-token-action \r\n\n\tmona-cat_octo/another_repo.test\t'
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

for repository in 'missing-slash' 'owner/' 'owner/.' 'owner/..'; do
  SCOPED_GIT_REPOSITORIES=$repository SCOPED_GIT_RUN='exit 99' assert_exit 1
  [[ $output == *"Invalid repository name '$repository'. Use owner/name." ]] || fail 'The repository error does not show its sentence.'
done
SCOPED_GIT_REPOSITORIES=$' \n\t\r' assert_exit 1
SCOPED_GIT_TOKEN='' assert_exit 1
SCOPED_GIT_RUN='' assert_exit 1
printf 'PASS invalid and absent inputs\n'

SCOPED_GIT_RUN='exit 37' assert_exit 37
SCOPED_GIT_RUN=$'false\nexit 99' assert_exit 1
SCOPED_GIT_RUN=$'false | true\nexit 99' assert_exit 1
# shellcheck disable=SC2016 # The child Bash process must expand this command.
SCOPED_GIT_RUN='[[ -z $unset_input ]]' assert_exit 0
[[ $output == '::add-mask::test-token-%25-only' ]] || fail 'The action did not mask the token.'
printf 'PASS exit code, Bash flags, and mask\n'

export GIT_CONFIG_COUNT=4
export GIT_CONFIG_KEY_2=credential.$GITHUB_SERVER_URL/mathematic-inc/scoped-git-token-action.helper
export GIT_CONFIG_KEY_3=credential.$GITHUB_SERVER_URL/mathematic-inc/scoped-git-token-action.git.helper
export GIT_CONFIG_VALUE_2='!f() { printf "%s\n" username=lower password=lower; }; f'
export GIT_CONFIG_VALUE_3=$GIT_CONFIG_VALUE_2
bash "$script"
printf 'PASS lower helper reset for both URL forms\n'

export SCOPED_GIT_RUN='
  export SCOPED_GIT_TOKEN=changed-test-token TEST_TOKEN=changed-test-token
  bash tests/credentials.sh present
'
bash "$script"
printf 'PASS token read at helper call\n'
