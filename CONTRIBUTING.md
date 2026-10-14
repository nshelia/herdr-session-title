# Contributing

## Develop locally

```sh
git clone https://github.com/nshelia/herdr-session-title
cd herdr-session-title
herdr plugin link .        # your running herdr now uses this checkout
```

Edits to `bin/herdr-session-title` take effect on the next event. After editing `herdr-plugin.toml`, run `herdr plugin unlink herdr-session-title && herdr plugin link .`

## Test

```sh
shellcheck -s sh bin/herdr-session-title tests/e2e.sh
sh tests/e2e.sh                       # uses herdr from PATH
HERDR=/path/to/herdr sh tests/e2e.sh  # a specific build
```

`tests/e2e.sh` starts a throwaway headless herdr server with its own `HOME` and socket, so it never touches your real session. It fakes an agent by setting a pane's terminal title and reporting agent state, then checks the metadata the plugin published. Add a case there for every behavior change.

## Keeping up with herdr

CI runs the e2e test against two herdr versions:

- **min**: the `min_herdr_version` in `herdr-plugin.toml`
- **latest**: the newest stable herdr release

It runs on every push and PR, and **daily**. If the daily run fails, CI opens an issue titled "Compatibility check failed against the latest herdr" (or comments on the open one). Dependabot keeps the GitHub Actions versions current.

When that issue opens:

1. Read the failing step. The test names say which behavior broke.
2. Check the herdr changelog (`gh release view -R ogulcancelik/herdr`) for changes to the APIs listed in [docs/how-it-works.md](docs/how-it-works.md#herdr-apis-this-depends-on).
3. Fix the script, and if the fix needs the new herdr, raise `min_herdr_version`.
4. Release (below) and close the issue.

## Release

1. Bump `version` in `herdr-plugin.toml`.
2. Add an entry to `CHANGELOG.md`.
3. Commit, then tag and push:

```sh
git tag v0.2.0 && git push origin main v0.2.0
gh release create v0.2.0 --notes-from-tag
```

Users get it with `herdr plugin install nshelia/herdr-session-title` again (or their plugin manager's update).
