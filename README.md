# Scoped Git token for GitHub Actions

`mathematic-inc/scoped-git-token-action` runs Bash commands, and Git in these
commands uses a GitHub token only for the repositories that you name.
The token is only in the environment of these commands, so later job steps have
no credential from this action.

The action writes no token to a file, Git config file, or remote URL.
Files can outlive a step and enter caches or artifacts.

## Usage

The example pins release `v2026.11.0` by its full commit, and you must pin a
release the same way.

```yaml
permissions:
  contents: read

steps:
  # actions/checkout v7.0.1
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
    with:
      persist-credentials: false
  # actions/create-github-app-token v3.3.0
  - uses: actions/create-github-app-token@64ab729a6294000f5aa4a4bc0b73d1f32bc45510
    id: app-token
    with:
      client-id: ${{ vars.APP_CLIENT_ID }}
      private-key: ${{ secrets.APP_PRIVATE_KEY }}
      owner: my-org
      repositories: private-tools
      permission-contents: read
  # mathematic-inc/scoped-git-token-action v2026.11.0
  - uses: mathematic-inc/scoped-git-token-action@bc7f1fae365ee7ae6b304713303b656df1096eeb
    with:
      token: ${{ steps.app-token.outputs.token }}
      repositories: |
        my-org/private-tools
      run: |
        git clone "$GITHUB_SERVER_URL/my-org/private-tools.git"
        bash private-tools/check.sh
```

Set `persist-credentials: false` on actions/checkout.
If not, Git commands in that checkout send its token, not this one.
Install the GitHub App on each repository.
Give the token only the permissions that your commands need.
The action needs Git 2.31 or later.

## Inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `token` | Required | GitHub token. Pass a secret or a masked step output, because the runner prints inputs before the action can mask them. |
| `repositories` | Required | One `owner/name` on each line. Write each name as it appears in the URLs. The action ignores blank lines and spaces or tabs around a name. |
| `run` | Required | Commands for `bash --noprofile --norc -e -o pipefail`. The step returns their exit code. The commands cannot set step outputs. |
| `working-directory` | `github.workspace` | Directory for the commands. A relative path starts at `github.workspace`. |

## Credential scope

The host comes from `GITHUB_SERVER_URL`, so the action supports GitHub
Enterprise Server.
Each repository has entries for both URL forms, with and without `.git`.
For each form, the action clears prior helpers, adds its helper, and sets `useHttpPath`.
It appends these entries after the job's current `GIT_CONFIG_COUNT` entries.

The helper reads the token from its environment when Git calls it.
The helper answers only `get`.
Its config value contains a variable reference, so `GIT_TRACE=1` does not print
the token.
The action sets `GIT_TERMINAL_PROMPT=0`, so Git fails at once when it has no credential.

The commands, and each program that they start, can read the token in `SCOPED_GIT_TOKEN`.
Limit the token to the named repositories. Run only trusted code.
Processes that the commands leave in the background keep the token until the
job ends.

## Development

```sh
bash tests/contracts.sh
shellcheck scoped-git-token.sh tests/*.sh
actionlint
```

## License

MIT. See [LICENSE](LICENSE).
