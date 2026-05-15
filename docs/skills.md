# Skills

Skills are Markdown files that instruct the agent on how to use a local capability or follow a multi-step workflow. They load at runtime from `~/.neoagent/agent-data/skills/`, so edits take effect without restarting the service.

## Built-in Skills

| Skill | Description |
|---|---|
| `browser.md` | Web browsing and scraping with Puppeteer |
| `cli.md` | Shell commands in a persistent PTY terminal |
| `files.md` | Read, write, and search host files |
| `memory.md` | Store and recall long-term facts |
| `messaging.md` | Send via Telegram, WhatsApp, Discord, Slack, Matrix, Teams, Google Chat, or webhooks |
| `system-stats.md` | CPU, memory, and disk usage |
| `weather.md` | Current weather via wttr.in |
| `ip-info.md` | Public IP and geolocation |
| `port-check.md` | Check if a TCP port is open |
| `ping-host.md` | Ping a host |
| `process-monitor.md` | List running processes |
| `disk-usage.md` | Directory size breakdown |
| `find-large-files.md` | Locate large files |
| `docker-status.md` | Docker container status |
| `tail-log.md` | Tail any log file |
| `news-hackernews.md` | Fetch top Hacker News stories |
| `qr-code.md` | Generate QR codes |
| `pdf-toolkit.md` | Inspect, extract, merge, split, compress PDFs |
| `git-summary.md` | Summarize git status, branches, commits, and diffs |
| `csv-toolkit.md` | Inspect and transform CSV or TSV files |
| `markdown-workbench.md` | Clean up, outline, and convert Markdown documents |

## Creating a Custom Skill

Add a Markdown file to `~/.neoagent/agent-data/skills/`:

```markdown
# My Skill Name

Brief description of what this skill does and when to use it.

## Usage

Step-by-step instructions or exact commands the agent should follow.
```

The agent reads all `.md` files in the skills directory on each turn. Keep skills focused. Include exact tool names or shell commands when precision matters. Don't store secrets in skill files.

**When to use a custom skill** — repeated workflows involving specific local paths, commands, or multi-step procedures. For connecting to third-party services, prefer official integrations or MCP tools instead.

## Skill Store

The **Skills** section in the UI includes a built-in catalog from `/api/store`. Skills install as Markdown files into the runtime skills directory — editable and removable after installation.

Catalog categories: system, network, info, document, data, and git helpers.

## MCP Tools

External tools connect via the [Model Context Protocol](https://modelcontextprotocol.io). Configure MCP servers in **Settings → MCP**. Connected tools appear alongside built-in skills automatically.

Use official integrations or MCP tools when they exist — they are more reliable than browser automation or shell scraping and easier to audit.
