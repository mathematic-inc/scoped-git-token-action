# Scoped Git token for GitHub Actions

`mathematic-inc/scoped-git-token-action` runs Bash commands with a GitHub token for the repositories you name.
The token stays in that process environment, so later job steps have no credential from this action.

The action writes no token to a file, Git config file, or remote URL.
Files can outlive a step and enter caches or artifacts.

## Usage

The example pins each action to a full commit.
This action has no release tag yet; its pin refers to the first implementation commit.

```yaml
permissions:
  contents: read

steps:
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
    with:
      persist-credentials: false
  - uses: actions/create-github-app-token@64ab729a6294000f5aa4a4bc0b73d1f32bc45510 # v3.3.0
    id: app-token
    with:
      client-id: ${{ vars.APP_CLIENT_ID }}
      private-key: ${{ secrets.APP_PRIVATE_KEY }}
      owner: my-org
      repositories: private-tools
      permission-contents: read
  - uses: mathematic-inc/scoped-git-token-action@85d76ff2c6e0aa7fe8bf90e72b76367624c59209 # Initial implementation
    with:
      token: ${{ steps.app-token.outputs.token }}
      repositories: |
        my-org/private-tools
      run: |
        git clone "$GITHUB_SERVER_URL/my-org/private-tools.git"
        bash private-tools/check.sh
```

Install the GitHub App on each target repository and grant it the permissions your commands need.
Use a token with those permissions.

## Inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `token` | Required | GitHub token. The action masks it in job logs. |
| `repositories` | Required | One `owner/name` per line. Allows outer spaces, tabs, and blank lines. |
| `run` | Required | Commands for `bash --noprofile --norc -e -o pipefail`. The step returns their exit code. |
| `working-directory` | Current directory | Directory for the commands. Accepts a relative or absolute path. |

Owner names allow letters, digits, and hyphens.
Repository names also allow underscores and periods, except `.` and `..` alone.
An invalid name fails with `Invalid repository name '<name>'; use owner/name.`
An empty repository list fails before any command executes.

## Credential scope

The host comes from `github.server_url`, so the action supports GitHub Enterprise Server.
Each repository has entries for both URL forms, with and without `.git`.
For each form, the action clears prior helpers, adds its helper, and sets `useHttpPath`.
It appends these entries after the job's current `GIT_CONFIG_COUNT` entries.

The helper reads the token from its environment when Git calls it and answers only `get`.
Its config value contains a variable reference, so `GIT_TRACE=1` does not print the token.
`GIT_TERMINAL_PROMPT=0` prevents a terminal prompt when Git has no credential.
The action preserves other job environment variables.

## Development

```sh
bash tests/contracts.sh
shellcheck scoped-git-token.sh tests/*.sh
actionlint
```

CI runs the local action on Ubuntu, macOS, and Windows with `github.token`.
The tests use `git credential fill` without network requests and never print its response.
They check both URL forms, scope, prior config, step isolation, input errors, exit codes, and trace output.
Script tests also check a custom host, lower helper reset, and the helper's operations.

## License

MIT. See [LICENSE](LICENSE).
