# herdr-session-title

[![CI](https://github.com/nshelia/herdr-session-title/actions/workflows/ci.yml/badge.svg)](https://github.com/nshelia/herdr-session-title/actions/workflows/ci.yml)

A [herdr](https://github.com/ogulcancelik/herdr) plugin that shows each agent's **session title** in the sidebar's Agents section.

Without it, every Claude Code pane in the sidebar reads `claude`. With it:

```
Agents                                   Agents
● claude                                 ● Fix login redirect
● claude                    →            ● Arize evals ticket status
○ claude                                 ○ Recorder uptime alerts on Telegram
```

Claude Code names each conversation after your first prompt and writes that name to the terminal title. The plugin reads it and publishes it to herdr as pane metadata. It works with any agent that sets a terminal title.

## Install

```sh
herdr plugin install nshelia/herdr-session-title
```

Requirements: herdr **0.9.3 or newer**, `jq`, macOS or Linux.

Titles appear the next time each agent changes state (starts or finishes a turn). To fill them in right away:

```sh
herdr plugin action invoke herdr-session-title.sync
```

## Show the title next to the agent name

By default the title replaces the agent name. To keep `claude` and show the title on a second line instead:

```sh
echo 0 > "$(herdr plugin config-dir herdr-session-title)/display-agent"
```

```toml
# ~/.config/herdr/config.toml
[ui.sidebar.agents]
rows = [["state_icon", "agent"], ["$session_title"]]
```

Then run `herdr server reload-config`.

## Settings

Each setting is a one-line file in `herdr plugin config-dir herdr-session-title`, or an environment variable set where the herdr server starts. The environment variable wins.

| File | Env var | Default | Effect |
| --- | --- | --- | --- |
| `display-agent` | `HERDR_SESSION_TITLE_DISPLAY_AGENT` | `1` | `1` replaces the agent name with the title. `0` keeps the agent name. |
| `max-length` | `HERDR_SESSION_TITLE_MAX` | `40` | Longer titles are cut and end with `…`. |

## Troubleshooting

**A row still says `claude`.** That session has no title yet. Claude Code titles a session after the first prompt; until then the terminal title is "Claude Code", which the plugin ignores.

**A renamed session shows the old title.** herdr doesn't notify plugins when a terminal title changes, so the plugin re-reads it on the agent's next state change. Run the sync action to update immediately.

**Nothing changes at all.** Check the plugin is enabled and look at its logs:

```sh
herdr plugin list --plugin herdr-session-title
herdr plugin log list --plugin herdr-session-title --limit 20
```

A `jq is required` message means `jq` isn't on the herdr server's `PATH`.

## Uninstall

```sh
herdr plugin uninstall herdr-session-title
```

## More

- [How it works](docs/how-it-works.md): events, the metadata it publishes, and the herdr APIs it depends on
- [Contributing](CONTRIBUTING.md): running the tests, releasing, and keeping up with herdr
- [Changelog](CHANGELOG.md)

## License

[MIT](LICENSE)
