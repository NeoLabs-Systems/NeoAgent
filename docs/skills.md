# Skills

Skills are Markdown files that teach the agent how to use local capabilities or follow a workflow. NeoAgent loads them at runtime from `~/.neoagent/agent-data/skills/` by default, so edits do not require a service restart.

## Built-in Skills

| Skill | Description |
|---|---|
| `browser.md` | Puppeteer-powered web browsing and scraping |
| `cli.md` | Execute shell commands in a persistent terminal |
| `files.md` | Read, write, and search files on the host |
| `memory.md` | Store and recall long-term memories |
| `messaging.md` | Send messages via connected messaging platforms such as WhatsApp, Telegram, Discord, Slack, Matrix, Teams, Google Chat, or webhook bridges |
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
| `news-hackernews.md` | Fetch Hacker News top stories |
| `qr-code.md` | Generate QR codes |
| `pdf-toolkit.md` | Inspect, extract, merge, split, and compress PDF files |
| `git-summary.md` | Summarize git status, branches, commits, and diffs |
| `csv-toolkit.md` | Inspect and transform CSV or TSV data files |
| `markdown-workbench.md` | Clean up, outline, and convert Markdown notes or docs |

## Adding a Skill

Create a Markdown file in `~/.neoagent/agent-data/skills/`:

```markdown
# My Skill Name

Brief description of what this skill does and when to use it.

## Usage

Explain the steps or commands the agent should follow.
```

The agent reads all `.md` files in the skills directory on each conversation turn. Keep each skill focused, include exact commands or tool names when they matter, and avoid storing secrets in skill files.

## Skill Store

The **Skills** section also exposes a built-in catalog through `/api/store`. Catalog entries install into the same runtime skills directory, so they stay GitHub-readable Markdown files and can be edited or removed after installation.

The catalog includes system, network, info, document, data, and git helpers such as disk usage, process monitoring, tail logs, finding large files, ping, DNS lookup, SSL certificate checks, weather, crypto prices, PDFs, CSV or TSV data, Markdown cleanup, and git summaries.

## MCP Tools

External tools are connected via the [Model Context Protocol](https://modelcontextprotocol.io). Configure MCP servers in the Flutter app under **Models / Settings -> MCP**. Connected tools appear alongside built-in skills automatically.

Use official integrations or structured MCP tools when they exist. They are usually safer and more reliable than browser automation or shell scraping.

See [Capabilities](capabilities.md) for the broader built-in agent tool surface beyond Markdown skills.
