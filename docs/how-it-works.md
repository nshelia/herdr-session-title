# How it works

The plugin is one POSIX shell script, [`bin/herdr-session-title`](../bin/herdr-session-title), wired up by [`herdr-plugin.toml`](../herdr-plugin.toml). It has no build step and no state.

## Flow

```
agent sets terminal title ──► herdr stores it as terminal_title_stripped
                                          │
herdr event (agent detected / state change)│
          │                               ▼
          └──► bin/herdr-session-title event
                  1. read pane_id from HERDR_PLUGIN_EVENT_JSON
                  2. herdr pane get <pane_id>
                  3. skip if no agent, placeholder title, or title unchanged
                  4. herdr pane report-metadata <pane_id> --title … --display-agent … --token session_title=…
```

`sync` does steps 3–4 for every pane in `herdr agent list`. It runs at server startup and from the **Refresh agent session titles** action.

## Hooks

| Manifest entry | When herdr runs it | Command |
| --- | --- | --- |
| `[[startup]]` | Server start, after the session is restored | `sync` |
| `[[events]] pane.agent_detected` | An agent starts in a pane | `event` |
| `[[events]] pane.agent_status_changed` | An agent goes working ↔ idle ↔ blocked | `event` |
| `[[actions]] sync` | You invoke it | `sync` |

There is no hook for "terminal title changed": herdr 0.9 only emits `pane.updated` to API subscribers, not to plugins. Agents rename sessions while working, so the next state change picks the new title up.

## What it publishes

All metadata is reported with `--source herdr-session-title`, so it doesn't overwrite metadata from other plugins or integrations.

| Field | Value | Used by |
| --- | --- | --- |
| `title` | session title | pane title, outer title plugins |
| `display_agent` | session title (unless `display-agent` is `0`) | the default Agents sidebar row |
| `tokens.session_title` | session title | custom sidebar rows: `["$session_title"]` |

## Which titles are ignored

Before the first prompt, agents show a generic title. The script skips these: empty, `Claude Code`, `claude`, `codex`, `OpenAI Codex`, `gemini`, and bare shell names. Leading status glyphs (`✳`, spinners) are stripped.

Add a new placeholder to `is_placeholder` if an agent shows one that slips through.

## herdr APIs this depends on

These are what can break when herdr changes. The CI e2e test exercises every one of them against both the minimum supported herdr and the latest release, daily.

- `herdr pane get` → `.result.pane.{pane_id, agent, title, terminal_title_stripped}`
- `herdr agent list` → `.result.agents[]` with the same fields
- `herdr pane report-metadata` flags: `--source`, `--agent`, `--title`, `--display-agent`, `--token`
- Plugin events `pane.agent_detected`, `pane.agent_status_changed`, with `.data.pane_id` in `HERDR_PLUGIN_EVENT_JSON`
- Plugin env vars `HERDR_BIN_PATH`, `HERDR_PLUGIN_CONFIG_DIR`
