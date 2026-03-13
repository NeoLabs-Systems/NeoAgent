# Skills

Skills are Markdown files in `~/.neoagent/agent-data/skills/` by default. They are loaded at runtime — no restart needed after editing.

## Built-in skills

| Skill | Description |
|---|---|
| `browser.md` | Puppeteer-powered web browsing and scraping |
| `cli.md` | Execute shell commands in a persistent terminal |
| `files.md` | Read, write, search files on the host |
| `memory.md` | Store and recall long-term memories |
| `messaging.md` | Send messages via Telegram, Discord, WhatsApp |
| `system-stats.md` | CPU, memory, disk usage |
| `weather.md` | Current weather via wttr.in |
| `ip-info.md` | Public IP and geolocation |
| `port-check.md` | Check if a TCP port is open |
| `ping-host.md` | Ping a host |
| `process-monitor.md` | List running processes |
| `disk-usage.md` | Directory size breakdown |
| `find-large-files.md` | Locate large files |
| `docker-status.md` | Docker container status |
| `tail-log.md` | Tail any log file |
| `news-hackernews.md` | Fetch Hacker News top stories |
| `qr-code.md` | Generate QR codes |
| `pdf-toolkit.md` | Inspect, extract, merge, split, and compress PDF files |
| `git-summary.md` | Summarize git status, branches, commits, and diffs |
| `csv-toolkit.md` | Inspect and transform CSV/TSV data files |
| `markdown-workbench.md` | Clean up, outline, and convert Markdown notes/docs |

## Adding a skill

Create a Markdown file in `~/.neoagent/agent-data/skills/`:

```markdown
# My Skill Name

Brief description of what this skill does and when to use it.

## Usage

Explain the steps or commands the agent should follow.
```

The agent reads all `.md` files in the skills directory on each conversation turn.

## MCP tools

External tools are connected via the [Model Context Protocol](https://modelcontextprotocol.io). Configure MCP servers in the web UI under **Settings → MCP**. Connected tools appear alongside built-in skills automatically.
