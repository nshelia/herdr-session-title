# herdr-session-title

A [herdr](https://herdr.dev) plugin that shows each agent's **session title** in the sidebar's Agents section, so instead of five rows that all say `claude` you see `Fix login redirect`, `Arize evals ticket status`, …

Claude Code (and most other agents) name the conversation after your first prompt and put that name in the terminal title. This plugin reads it and publishes it as pane metadata.

## Install

```sh
herdr plugin install nshelia/herdr-session-title
```

Requires `jq`.

## What it sets

For every agent pane with a real session title:

- `--display-agent` — replaces the agent name in the default Agents row
- `--title` — the pane title
- `$session_title` token — for custom sidebar rows

Want to keep the agent name and show the title on a second line instead? Turn off `display-agent` and use the token:

```sh
echo 0 > "$(herdr plugin config-dir herdr-session-title)/display-agent"
```

```toml
# ~/.config/herdr/config.toml
[ui.sidebar.agents]
rows = [["state_icon", "agent"], ["$session_title"]]
```

## Settings

| File in `herdr plugin config-dir herdr-session-title` | Env var | Default | |
| --- | --- | --- | --- |
| `display-agent` | `HERDR_SESSION_TITLE_DISPLAY_AGENT` | `1` | Replace the agent name with the title |
| `max-length` | `HERDR_SESSION_TITLE_MAX` | `40` | Truncate long titles |

## When it updates

On startup, when an agent is detected in a pane, and on every agent state change. Run the **Refresh agent session titles** action to force a full refresh.

## Local development

```sh
herdr plugin link .
herdr plugin action invoke herdr-session-title.sync
```

## License

MIT
