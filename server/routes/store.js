const express = require('express');
const router = express.Router();
const path = require('path');
const { requireAuth } = require('../middleware/auth');
const { AGENT_DATA_DIR } = require('../../runtime/paths');

router.use(requireAuth);

const SKILLS_DIR = path.join(AGENT_DATA_DIR, 'skills');

// ── Skill catalog ─────────────────────────────────────────────────────────────
// Each entry: id (becomes filename <id>.md), name, description, category, icon, content
const CATALOG = [

  // ── SYSTEM ──────────────────────────────────────────────────────────────────
  {
    id: 'disk-usage',
    name: 'Disk Usage',
    description: 'Show disk space usage for all mounted filesystems.',
    category: 'system',
    icon: '💾',
    content: `---
name: disk-usage
description: Show disk space usage for all mounted filesystems
category: system
icon: 💾
enabled: true
---

Run \`df -h\` to show disk usage. If the user asks about a specific path, run \`du -sh <path>\`. Present the output in a readable table, highlight any filesystems above 80% usage.`
  },

  {
    id: 'system-stats',
    name: 'System Stats',
    description: 'Report CPU, RAM, load average and uptime.',
    category: 'system',
    icon: '📊',
    content: `---
name: system-stats
description: Report CPU, RAM, load average and uptime
category: system
icon: 📊
enabled: true
---

Run these commands and summarise the results:
- \`uptime\` — load average and uptime
- \`free -m\` (Linux) or \`vm_stat\` (macOS) — memory usage
- \`nproc\` or \`sysctl -n hw.logicalcpu\` — CPU count

Combine into a short dashboard-style summary.`
  },

  {
    id: 'process-monitor',
    name: 'Process Monitor',
    description: 'List the top 15 processes by CPU or memory usage.',
    category: 'system',
    icon: '⚙️',
    content: `---
name: process-monitor
description: List the top 15 processes by CPU or memory usage
category: system
icon: ⚙️
enabled: true
---

Run \`ps aux --sort=-%cpu | head -16\` on Linux or \`ps aux -r | head -16\` on macOS to show top CPU processes. If the user asks for memory, use \`ps aux --sort=-%mem | head -16\`. Format as a readable table with PID, command, CPU%, MEM%.`
  },

  {
    id: 'tail-log',
    name: 'Tail Log File',
    description: 'Show the last N lines of any log file, with optional filtering.',
    category: 'system',
    icon: '📋',
    content: `---
name: tail-log
description: Show the last N lines of any log file, with optional filtering
category: system
icon: 📋
enabled: true
---

Run \`tail -n <lines> <file>\` to show recent log lines. Default to 50 lines if not specified. If the user provides a filter keyword, pipe through \`grep <keyword>\`. For common logs, suggest: /var/log/syslog, /var/log/nginx/error.log, ./logs/app.log etc.`
  },

  {
    id: 'find-large-files',
    name: 'Find Large Files',
    description: 'Find the largest files in a directory tree.',
    category: 'system',
    icon: '🔍',
    content: `---
name: find-large-files
description: Find the largest files in a directory tree
category: system
icon: 🔍
enabled: true
---

Run \`find <dir> -type f -exec du -sh {} + 2>/dev/null | sort -rh | head -20\` to list the 20 largest files. Default to current directory if none provided. Present as a ranked list with human-readable sizes.`
  },

  // ── NETWORK ─────────────────────────────────────────────────────────────────
  {
    id: 'ping-host',
    name: 'Ping Host',
    description: 'Ping a hostname or IP and report latency and packet loss.',
    category: 'network',
    icon: '📡',
    content: `---
name: ping-host
description: Ping a hostname or IP and report latency and packet loss
category: network
icon: 📡
enabled: true
---

Run \`ping -c 5 <host>\` to send 5 ICMP packets. Report average RTT, packet loss %, and whether the host is reachable. If the host is unreachable, suggest checking DNS or firewall.`
  },

  {
    id: 'ip-info',
    name: 'IP Info',
    description: 'Get your public IP address and geolocation details.',
    category: 'network',
    icon: '🌐',
    content: `---
name: ip-info
description: Get your public IP address and geolocation details
category: network
icon: 🌐
enabled: true
---

Make a GET request to \`https://ipinfo.io/json\` (no auth needed for basic info). Display the IP, city, region, country, org (ISP), and timezone in a clean summary. If the user asks about a specific IP, use \`https://ipinfo.io/<ip>/json\`.`
  },

  {
    id: 'ssl-check',
    name: 'SSL Certificate Check',
    description: 'Check the SSL certificate expiry date for any domain.',
    category: 'network',
    icon: '🔒',
    content: `---
name: ssl-check
description: Check the SSL certificate expiry date for any domain
category: network
icon: 🔒
enabled: true
---

Run \`echo | openssl s_client -connect <domain>:443 -servername <domain> 2>/dev/null | openssl x509 -noout -dates\` to get cert validity dates. Calculate how many days until expiry. Warn if < 30 days, alert if < 7 days, or if already expired.`
  },

  {
    id: 'port-check',
    name: 'Port Check',
    description: 'Test whether a specific TCP port is open on a host.',
    category: 'network',
    icon: '🔌',
    content: `---
name: port-check
description: Test whether a specific TCP port is open on a host
category: network
icon: 🔌
enabled: true
---

Run \`nc -zv -w3 <host> <port> 2>&1\` or \`curl -s --connect-timeout 3 telnet://<host>:<port>\` to test connectivity. Report clearly: open or closed/filtered, and response time if measurable. Common ports to suggest: 80 (HTTP), 443 (HTTPS), 22 (SSH), 3306 (MySQL), 5432 (Postgres), 6379 (Redis).`
  },

  {
    id: 'dns-lookup',
    name: 'DNS Lookup',
    description: 'Perform DNS lookups (A, MX, TXT, CNAME records) for any domain.',
    category: 'network',
    icon: '🗺️',
    content: `---
name: dns-lookup
description: Perform DNS lookups (A, MX, TXT, CNAME records) for any domain
category: network
icon: 🗺️
enabled: true
---

Use \`dig <domain> <type>\` or \`nslookup\` to query DNS records. Default to A records. If the user says "all records", run dig for A, MX, TXT, CNAME in one go. Present results cleanly without raw dig headers.`
  },

  // ── INFO ────────────────────────────────────────────────────────────────────
  {
    id: 'weather',
    name: 'Weather',
    description: 'Get current weather and a 3-day forecast for any city.',
    category: 'info',
    icon: '🌤️',
    content: `---
name: weather
description: Get current weather and a 3-day forecast for any city
category: info
icon: 🌤️
enabled: true
---

Make a GET request to \`https://wttr.in/<city>?format=j1\` (returns JSON). Parse:
- current_condition[0]: temp_C, weatherDesc, humidity, windspeedKmph, feels_like
- weather[0..2]: date, maxtempC, mintempC, hourly[4].weatherDesc (midday)

Present as a clean weather card: current conditions + 3-day forecast with icons. URL-encode city names with spaces.`
  },

  {
    id: 'crypto-price',
    name: 'Crypto Price',
    description: 'Look up live cryptocurrency prices from CoinGecko.',
    category: 'info',
    icon: '₿',
    content: `---
name: crypto-price
description: Look up live cryptocurrency prices from CoinGecko
category: info
icon: ₿
enabled: true
---

Use the CoinGecko free API (no key needed):
- Single coin: \`GET https://api.coingecko.com/api/v3/simple/price?ids=<id>&vs_currencies=usd,eur&include_24hr_change=true\`
- Common IDs: bitcoin, ethereum, solana, cardano, dogecoin, ripple, polkadot, chainlink, litecoin, avalanche-2

Show price in USD and EUR, 24h change %, and a trend arrow ↑↓. If the user uses a ticker (BTC), map it to the CoinGecko ID first.`
  },

  {
    id: 'exchange-rate',
    name: 'Exchange Rate',
    description: 'Get live currency exchange rates between any two currencies.',
    category: 'info',
    icon: '💱',
    content: `---
name: exchange-rate
description: Get live currency exchange rates between any two currencies
category: info
icon: 💱
enabled: true
---

Use the free Open Exchange Rates API:
\`GET https://open.er-api.com/v6/latest/<base_currency>\`

Example: \`https://open.er-api.com/v6/latest/USD\` returns rates for all currencies relative to USD.
Show the requested conversion with the exact rate and the last updated time. If the user gives an amount (e.g. "200 EUR to GBP"), calculate and show the converted value.`
  },

  {
    id: 'world-time',
    name: 'World Time',
    description: 'Show the current local time in major cities around the world.',
    category: 'info',
    icon: '🕐',
    content: `---
name: world-time
description: Show the current local time in major cities around the world
category: info
icon: 🕐
enabled: true
---

Run \`date\` for local time. Get world times via the API:
\`GET https://worldtimeapi.org/api/timezone/<Region/City>\`

Show a table of current times for: New York (America/New_York), London (Europe/London), Berlin (Europe/Berlin), Dubai (Asia/Dubai), Singapore (Asia/Singapore), Tokyo (Asia/Tokyo), Sydney (Australia/Sydney). Format as HH:MM timezone with day name.`
  },

  {
    id: 'news-hackernews',
    name: 'Hacker News Top Stories',
    description: 'Fetch the top 10 stories from Hacker News right now.',
    category: 'info',
    icon: '📰',
    content: `---
name: news-hackernews
description: Fetch the top 10 stories from Hacker News right now
category: info
icon: 📰
enabled: true
---

1. GET \`https://hacker-news.firebaseio.com/v0/topstories.json\` → get array of IDs
2. Take the first 10 IDs
3. For each ID, GET \`https://hacker-news.firebaseio.com/v0/item/<id>.json\` → title, url, score, by, descendants
Present as a numbered list: score points | title | by author (N comments). Link the title.`
  },

  // ── DEV ─────────────────────────────────────────────────────────────────────
  {
    id: 'git-summary',
    name: 'Git Summary',
    description: 'Show recent commits, current branch, and status for a git repo.',
    category: 'dev',
    icon: '🌿',
    content: `---
name: git-summary
description: Show recent commits, current branch, and status for a git repo
category: dev
icon: 🌿
enabled: true
---

Run in the user's specified directory (default: current working directory):
1. \`git log --oneline -10\` — last 10 commits
2. \`git status --short\` — dirty files
3. \`git branch --show-current\` — current branch
4. \`git remote -v\` — remotes

Present as a structured git dashboard. Note any uncommitted changes or detached HEAD.`
  },

  {
    id: 'pdf-toolkit',
    name: 'PDF Toolkit',
    description: 'Inspect, extract, split, merge, compress, and rearrange PDF files.',
    category: 'productivity',
    icon: '📄',
    content: `---
name: pdf-toolkit
description: Inspect, extract, split, merge, compress, and rearrange PDF files
category: productivity
icon: 📄
enabled: true
---

Work with PDF files using whatever is available on the machine. Prefer tools in this order when relevant:
- \`pdfinfo\`, \`pdftotext\`, \`pdftoppm\`, \`pdftocairo\` from Poppler for inspection, text extraction, and page rendering
- \`qpdf\` for splitting, merging, rotating, decrypting, and page selection
- \`pdftk\` for merge/split/stamp workflows if available
- \`mutool\` for extracting text, objects, and cleaning PDFs
- \`gs\` (Ghostscript) for compression or PDF regeneration

Workflow:
1. Verify the input file exists.
2. Check which PDF utilities are installed with \`which\`.
3. Choose the safest tool for the requested operation.
4. Write outputs next to the source file unless the user specifies a destination.
5. Report the output path, page counts, and any limitations clearly.

Common tasks:
- Inspect a PDF with \`pdfinfo <file.pdf>\`
- Extract text with \`pdftotext <file.pdf> -\` or \`pdftotext -layout <file.pdf> -\`
- Merge PDFs with \`qpdf --empty --pages a.pdf b.pdf -- out.pdf\`
- Split pages with \`qpdf in.pdf --pages in.pdf 1-5 -- out.pdf\`
- Reorder or remove pages with \`qpdf in.pdf --pages in.pdf 1,3,5-7 -- out.pdf\`
- Compress via Ghostscript:
\`gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile=out.pdf in.pdf\`

Preserve the original file unless the user explicitly asks to overwrite it.`
  },

  {
    id: 'docker-status',
    name: 'Docker Status',
    description: 'List all running and stopped Docker containers with their status.',
    category: 'dev',
    icon: '🐳',
    content: `---
name: docker-status
description: List all running and stopped Docker containers with their status
category: dev
icon: 🐳
enabled: true
---

Run \`docker ps -a --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}"\` to list all containers. Also run \`docker images --format "table {{.Repository}}:{{.Tag}}\\t{{.Size}}"\` to show local images.
Highlight running vs stopped vs exited. If Docker isn't installed/running, say so clearly.`
  },

  {
    id: 'npm-outdated',
    name: 'NPM Outdated Check',
    description: 'Check for outdated npm packages in a Node.js project.',
    category: 'dev',
    icon: '📦',
    content: `---
name: npm-outdated
description: Check for outdated npm packages in a Node.js project
category: dev
icon: 📦
enabled: true
---

Run \`npm outdated --json\` in the project directory. Parse the JSON and display as a table:
Package | Current | Wanted | Latest | Type (dep/devDep)

Categorise: minor updates (wanted > current), major updates (latest >> current). Suggest running \`npm update\` for minor updates or manual upgrades for majors. Handle "everything up to date" gracefully.`
  },

  {
    id: 'run-tests',
    name: 'Run Tests',
    description: 'Run the test suite for a project and summarise results.',
    category: 'dev',
    icon: '✅',
    content: `---
name: run-tests
description: Run the test suite for a project and summarise results
category: dev
icon: ✅
enabled: true
---

Check what test runner is configured (look at package.json scripts.test). Then run \`npm test\` (or \`yarn test\`, \`pytest\`, etc. as appropriate). Capture stdout/stderr.
Summarise: total tests, passed, failed, skipped. If failures occur, show the first 3 failed test names and errors. Do NOT truncate error details — they're important.`
  },

  {
    id: 'http-debug',
    name: 'HTTP Debug',
    description: 'Make a detailed HTTP request and inspect headers, status, timing.',
    category: 'dev',
    icon: '🔎',
    content: `---
name: http-debug
description: Make a detailed HTTP request and inspect headers, status, timing
category: dev
icon: 🔎
enabled: true
---

Use the http_request tool to make the request with full header capture. Also run \`curl -o /dev/null -s -w "\\n%{http_code} | %{time_total}s | %{size_download} bytes\\n" <url>\` for timing. Report:
- Status code and meaning
- Response time
- Key headers (Content-Type, Cache-Control, X-Frame-Options, etc.)
- Body preview (first 500 chars)
- Any redirects`
  },

  // ── PRODUCTIVITY ─────────────────────────────────────────────────────────────
  {
    id: 'summarize-url',
    name: 'Summarize URL',
    description: 'Fetch a webpage and give a concise summary of its content.',
    category: 'productivity',
    icon: '📄',
    content: `---
name: summarize-url
description: Fetch a webpage and give a concise summary of its content
category: productivity
icon: 📄
enabled: true
---

Use http_request to GET the URL. Extract text content from the HTML (skip scripts, styles, nav). Write a structured summary:
- **What it is**: 1 sentence
- **Key points**: 3–5 bullet points
- **Takeaway**: most important thing to know

Keep total summary under 200 words. If the URL fails or returns non-HTML, say so.`
  },

  {
    id: 'wikipedia',
    name: 'Wikipedia Summary',
    description: 'Get a Wikipedia article summary for any topic.',
    category: 'productivity',
    icon: '📚',
    content: `---
name: wikipedia
description: Get a Wikipedia article summary for any topic
category: productivity
icon: 📚
enabled: true
---

Use the Wikipedia REST API:
\`GET https://en.wikipedia.org/api/rest_v1/page/summary/<title>\`

URL-encode the title (replace spaces with underscores). The response contains \`extract\` (plain text summary) and \`content_urls.desktop.page\` (full article link).

Show the summary with the article URL. If the topic resolves to a disambiguation page, show the top options. Support language override via \`https://<lang>.wikipedia.org/...\`.`
  },

  {
    id: 'translate',
    name: 'Translate Text',
    description: 'Translate any text to a target language.',
    category: 'productivity',
    icon: '🌍',
    content: `---
name: translate
description: Translate any text to a target language
category: productivity
icon: 🌍
enabled: true
---

Use the LibreTranslate free API:
\`POST https://libretranslate.com/translate\`
Body: \`{"q": "<text>", "source": "auto", "target": "<lang_code>", "format": "text"}\`

Common language codes: en, de, fr, es, it, pt, nl, ru, zh, ja, ko, ar.
Show the translation clearly, note the detected source language. If the API fails, fall back to using your own translation ability with a note.`
  },

  {
    id: 'quick-note',
    name: 'Quick Note',
    description: 'Save a timestamped note to a notes file on disk.',
    category: 'productivity',
    icon: '📝',
    content: `---
name: quick-note
description: Save a timestamped note to a notes file on disk
category: productivity
icon: 📝
enabled: true
---

Append the note to \`~/notes.md\` (or a user-specified file) with this format:
\`\`\`
## 2025-01-15 14:32
<note content>
\`\`\`
Use \`echo\` or \`tee -a\` to append. Confirm the note was saved and show the file path. If the file doesn't exist, create it with a \`# Notes\` header first.`
  },

  {
    id: 'pomodoro',
    name: 'Pomodoro Timer',
    description: 'Start a Pomodoro focus timer with a desktop notification at the end.',
    category: 'productivity',
    icon: '🍅',
    content: `---
name: pomodoro
description: Start a Pomodoro focus timer with a desktop notification at the end
category: productivity
icon: 🍅
enabled: true
---

Default: 25-minute work session followed by a 5-minute break. Run in background:
\`\`\`bash
(sleep 1500 && osascript -e 'display notification "Pomodoro complete! Take a break." with title "🍅 Pomodoro"' 2>/dev/null || notify-send "🍅 Pomodoro" "Complete! Take a break." 2>/dev/null || echo "POMODORO DONE") &
\`\`\`
Print the PID and end time so the user can track it. Support custom durations.`
  },

  // ── GOOGLE ──────────────────────────────────────────────────────────────────
  {
    id: 'gogcli',
    name: 'Google Suite (gogcli)',
    description: 'Control Gmail, Calendar, Drive, Tasks, Contacts, Sheets, Chat and more via the gog CLI.',
    category: 'productivity',
    icon: '🌐',
    content: `---
name: gogcli
description: Control Gmail, Calendar, Drive, Tasks, Contacts, Sheets, Chat and more via the gog CLI
category: productivity
icon: 🌐
trigger: gmail|calendar|drive|tasks|contacts|sheets|google
enabled: true
source: https://github.com/steipete/gogcli
---

## Overview
\`gog\` (gogcli) is a fast, JSON-first CLI for Google Workspace services. Install via:
\`\`\`
brew install steipete/tap/gogcli
\`\`\`
Use \`--json\` for machine-readable output.

## Credential Storage (NeoAgent)
Store the Google account email in API_KEYS.json so you can always retrieve it:
\`\`\`
memory_write target=api_keys content={"gog_account": "you@gmail.com"}
\`\`\`
For non-interactive / headless runs, also store the keyring password:
\`\`\`
memory_write target=api_keys content={"gog_account": "you@gmail.com", "gog_keyring_password": "<your-keyring-password>"}
\`\`\`
Before every \`gog\` command, read back these keys:
\`\`\`
memory_read target=api_keys
\`\`\`
Then run gog with the stored values:
\`\`\`bash
export GOG_ACCOUNT="<gog_account from api_keys>"
export GOG_KEYRING_BACKEND=file                       # use on-disk encrypted keyring (no Keychain prompts)
export GOG_KEYRING_PASSWORD="<gog_keyring_password from api_keys>"  # if set
gog ...
\`\`\`

## First-Time Setup (run once manually by the user)
\`\`\`bash
gog auth credentials ~/Downloads/client_secret_....json  # store OAuth client credentials
gog auth keyring file                                     # switch to file backend (avoids Keychain prompts)
gog auth add you@gmail.com                               # authorize account — opens browser
gog auth status                                          # verify auth state
gog auth list                                            # list stored accounts
\`\`\`
After setup, save the account email with memory_write (above) so the agent can use it automatically.

## Gmail
\`\`\`bash
gog gmail search 'newer_than:7d is:unread' --max 10 --json
gog gmail thread get <threadId>
gog gmail send --to a@b.com --subject "Subject" --body "Body"
gog gmail send --to a@b.com --subject "Subject" --body-html "<p>Hi</p>"
gog gmail labels list
gog gmail thread modify <threadId> --add STARRED --remove INBOX
\`\`\`

## Calendar
\`\`\`bash
gog calendar events primary --today --json
gog calendar events primary --week
gog calendar search "standup" --days 7 --json
gog calendar create primary --summary "Meeting" --from 2026-01-15T10:00:00Z --to 2026-01-15T11:00:00Z --attendees "a@b.com"
gog calendar freebusy --calendars primary --from 2026-01-15T00:00:00Z --to 2026-01-16T00:00:00Z
gog calendar delete primary <eventId> --force
\`\`\`

## Drive
\`\`\`bash
gog drive ls --max 20 --json
gog drive search "invoice" --max 20 --json
gog drive upload ./file.pdf
gog drive download <fileId> --out ./file.pdf
gog drive share <fileId> --to user --email user@example.com --role reader
\`\`\`

## Tasks
\`\`\`bash
gog tasks lists --json
gog tasks list <tasklistId> --json
gog tasks add <tasklistId> --title "Task title" --due 2026-02-01
gog tasks done <tasklistId> <taskId>
\`\`\`

## Contacts
\`\`\`bash
gog contacts search "John" --max 20 --json
gog contacts create --given "Jane" --family "Doe" --email "jane@example.com"
\`\`\`

## Sheets
\`\`\`bash
gog sheets metadata <spreadsheetId>
gog sheets get <spreadsheetId> 'Sheet1!A1:D10' --json
gog sheets update <spreadsheetId> 'Sheet1!A1' 'val1|val2,val3|val4'
gog sheets append <spreadsheetId> 'Sheet1!A:C' 'new|row|data'
\`\`\`

## Docs / Slides
\`\`\`bash
gog docs cat <docId>
gog docs export <docId> --format pdf --out ./doc.pdf
gog docs sed <docId> 's/old/new/g'
gog slides export <presentationId> --format pptx --out ./deck.pptx
\`\`\`

## Tips
- Pipe JSON output to \`jq\` for filtering: \`gog --json gmail search 'is:unread' | jq '.threads[].id'\`
- Use \`GOG_ENABLE_COMMANDS=gmail,calendar\` to sandbox allowed commands
- \`--plain\` outputs stable TSV for shell scripting
- Calendar JSON includes \`startDayOfWeek\` and localized time fields, useful for scheduling logic`
  },

  // ── COMMUNITY ────────────────────────────────────────────────────────────────
  {
    id: 'answeroverflow',
    name: 'Answer Overflow',
    description: 'Search indexed Discord community discussions for coding answers via Answer Overflow.',
    category: 'productivity',
    icon: '💬',
    content: `---
name: answeroverflow
description: Search indexed Discord community discussions for coding answers via Answer Overflow
category: productivity
icon: 💬
trigger: discord|answeroverflow|community support
enabled: true
source: https://github.com/AnswerOverflow/AnswerOverflow
---

## What is Answer Overflow?
Answer Overflow indexes public Discord support channels and makes them searchable via Google and direct API. Perfect for finding answers that only exist in Discord conversations — from servers like Valorant, Cloudflare, C#, Nuxt, and thousands more.

## Quick Search (via Google)
\`\`\`bash
# Best approach — Answer Overflow results appear in Google
web_search "site:answeroverflow.com prisma connection pooling"
web_search "site:answeroverflow.com nextjs app router error"
web_search "site:answeroverflow.com discord.js slash commands"
\`\`\`

## Fetch Thread Content
\`\`\`bash
# Markdown format (preferred for agents)
http_request GET https://www.answeroverflow.com/m/<message-id>
# Add Accept: text/markdown header, or use /m/ prefix URL
\`\`\`

URL patterns:
- Thread: \`https://www.answeroverflow.com/m/<message-id>\`
- Server: \`https://www.answeroverflow.com/c/<server-slug>\`
- Channel: \`https://www.answeroverflow.com/c/<server-slug>/<channel-slug>\`

## MCP Server
Answer Overflow exposes an MCP server at \`https://www.answeroverflow.com/mcp\`:

| Tool | Description |
|------|-------------|
| \`search_answeroverflow\` | Search all indexed communities; filter by server/channel ID |
| \`search_servers\` | Discover indexed Discord servers |
| \`get_thread_messages\` | Get all messages from a specific thread |
| \`find_similar_threads\` | Find threads related to a given thread |

To add it as an MCP server in NeoAgent: command \`npx -y @answeroverflow/mcp\`

## Tips
- Results are real Discord conversations — context may be informal
- Threads often have back-and-forth before the solution; read the whole thread
- Check the server/channel name to understand context (official support vs community)
- Many major open-source projects index their Discord support channels here`
  },

  // ── FUN ─────────────────────────────────────────────────────────────────────
  {
    id: 'random-joke',
    name: 'Random Joke',
    description: 'Fetch a random joke (clean, programmer or general).',
    category: 'fun',
    icon: '😄',
    content: `---
name: random-joke
description: Fetch a random joke (clean, programmer or general)
category: fun
icon: 😄
enabled: true
---

GET \`https://v2.jokeapi.dev/joke/Programming,Miscellaneous?blacklistFlags=nsfw,racist,sexist,explicit\`

The response has either a single \`joke\` field or a two-part \`setup\`/\`delivery\`. Present it naturally — pause before the punchline in delivery style. If the user asks for a specific category (dark, pun, etc.), adjust the URL accordingly.`
  },

  {
    id: 'random-quote',
    name: 'Random Quote',
    description: 'Get a random motivational or philosophical quote.',
    category: 'fun',
    icon: '💭',
    content: `---
name: random-quote
description: Get a random motivational or philosophical quote
category: fun
icon: 💭
enabled: true
---

GET \`https://api.quotable.io/random\`

Show: \`"<content>"\` — *<author>*

If the user specifies a topic or author, use:
\`https://api.quotable.io/random?tags=<tag>\` (common tags: technology, wisdom, success, life, motivational, literature, science)
\`https://api.quotable.io/quotes?author=<slug>\` for a specific author.`
  },

  {
    id: 'random-fact',
    name: 'Random Fact',
    description: 'Get a random interesting fact.',
    category: 'fun',
    icon: '🧠',
    content: `---
name: random-fact
description: Get a random interesting fact
category: fun
icon: 🧠
enabled: true
---

GET \`https://uselessfacts.jsph.pl/api/v2/facts/random?language=en\` for a random fact.
Alternatively: \`https://api.api-ninjas.com/v1/facts?limit=1\` (no key needed for free tier).
Present the fact naturally, optionally adding a brief "why this is interesting" comment if it's not immediately obvious.`
  },

  {
    id: 'word-definition',
    name: 'Word Definition',
    description: 'Look up the definition, pronunciation and examples for any word.',
    category: 'fun',
    icon: '📖',
    content: `---
name: word-definition
description: Look up the definition, pronunciation and examples for any word
category: fun
icon: 📖
enabled: true
---

GET \`https://api.dictionaryapi.dev/api/v2/entries/en/<word>\`

Extract and display:
- Pronunciation (phonetic)
- Part of speech
- Primary definition(s)
- Example sentence if available
- Synonyms (first 5)

If the word isn't found, suggest similar spellings. Supports multiple meanings grouped by part of speech.`
  },

  {
    id: 'qr-code',
    name: 'QR Code Generator',
    description: 'Generate a QR code image URL for any text or URL.',
    category: 'fun',
    icon: '⬛',
    content: `---
name: qr-code
description: Generate a QR code image URL for any text or URL
category: fun
icon: ⬛
enabled: true
---

Use the QR Server API (no auth):
\`https://api.qrserver.com/v1/create-qr-code/?data=<encoded_text>&size=300x300&margin=10\`

URL-encode the input data. Provide the direct image URL that the user can open in a browser or embed. Also calculate: at the default error correction level (M), the QR can hold the given text reliably up to X characters.`
  },

  // ── DEV (continued) ──────────────────────────────────────────────────────────
  {
    id: 'github',
    name: 'GitHub',
    description: 'Interact with GitHub repos, PRs, issues, branches, CI and releases using git and the gh CLI.',
    category: 'dev',
    icon: '🐙',
    content: `---
name: github
description: Interact with GitHub repos, PRs, issues, branches, CI and releases using git and the gh CLI
trigger: When the user asks to clone a repo, create a PR, open/close issues, check CI status, fork, review diffs, manage branches, or do anything GitHub-related
category: dev
icon: 🐙
enabled: true
---

# GitHub Skill

Use \`git\` for local version control and \`gh\` (GitHub CLI) for GitHub-specific actions.
Always verify both tools are available: \`which git && which gh\`.
If \`gh\` is not authenticated, prompt the user to run \`gh auth login\`.

## Repo Status & Info
\`\`\`
gh repo view                          # show current repo overview
gh repo view <owner>/<repo>           # show a specific repo
git status                            # show working tree state
git log --oneline -20                 # last 20 commits
git diff                              # unstaged changes
git diff --staged                     # staged changes
\`\`\`

## Clone & Fork
\`\`\`
gh repo clone <owner>/<repo>          # clone via gh (sets up remote automatically)
gh repo fork <owner>/<repo> --clone   # fork and clone in one step
\`\`\`

## Branches
\`\`\`
git checkout -b <branch>              # create and switch to new branch
git branch -a                         # list all branches (local + remote)
git push -u origin <branch>           # push new branch to origin
git branch -d <branch>                # delete local branch
gh repo sync                          # sync fork with upstream
\`\`\`

## Commits & Push
\`\`\`
git add -A && git commit -m "<msg>"   # stage all and commit
git push                              # push to tracked remote branch
git pull --rebase                     # pull with rebase
\`\`\`

## Pull Requests
\`\`\`
gh pr create --title "<title>" --body "<body>"   # open a PR
gh pr list                                        # list open PRs
gh pr view <number>                               # view a specific PR
gh pr checkout <number>                           # check out a PR branch locally
gh pr merge <number> --squash                     # merge PR (squash)
gh pr review <number> --approve                   # approve a PR
gh pr review <number> --request-changes -b "<feedback>"
gh pr close <number>                              # close without merging
gh pr status                                      # PRs involving you
\`\`\`

## Issues
\`\`\`
gh issue create --title "<title>" --body "<body>"  # create issue
gh issue list                                       # list open issues
gh issue view <number>                              # view an issue
gh issue close <number>                             # close an issue
gh issue comment <number> -b "<comment>"            # add a comment
gh issue assign <number> --assignee @me             # assign to yourself
\`\`\`

## Releases & Tags
\`\`\`
gh release create <tag> --title "<title>" --notes "<notes>"
gh release list
gh release view <tag>
git tag -a v1.0.0 -m "Release v1.0.0" && git push --tags
\`\`\`

## CI / Actions
\`\`\`
gh run list                           # list recent workflow runs
gh run view <run-id>                  # view a run's details and logs
gh run watch <run-id>                 # stream live logs
gh workflow list                      # list workflows
gh workflow run <workflow-file>       # trigger a workflow manually
\`\`\`

## Presentation Tips
- For pr/issue lists, format as a table: number, title, author, date.
- For git log, show short hash, message, and relative date.
- For CI runs, summarise: ✅ success / ❌ failure / ⏳ in progress per job.
- Confirm with the user before any repo-modifying operation (push, merge, delete).`
  },

  // ── RESEARCH ─────────────────────────────────────────────────────────────────
  {
    id: 'deep-research',
    name: 'Deep Research',
    description: 'Conduct thorough multi-source research on any topic and synthesise findings into a structured report.',
    category: 'research',
    icon: '🔬',
    content: `---
name: deep-research
description: Conduct thorough multi-source research on any topic, synthesising findings into a structured report
trigger: When the user asks for deep research, a detailed investigation, a comprehensive overview, or wants to understand a complex topic in depth
category: research
icon: 🔬
enabled: true
---

# Deep Research Skill

Perform iterative, multi-source research by combining web searches, page reads, and cross-referencing. Don't stop at the first result — go wide, then go deep.

## Research Process

### 1. Clarify the Query
Decompose the topic into 3–5 sub-questions that together fully answer the user's request. State them so the user can correct scope before you begin.

### 2. Broad Discovery (go wide)
Run multiple searches using varied queries and angles:
- Direct topic searches: \`<topic> overview\`, \`<topic> explained\`
- Authoritative sources: \`site:en.wikipedia.org <topic>\`, \`site:arxiv.org <topic>\`
- Recent developments: \`<topic> 2025\`, \`<topic> latest research\`
- Opposing views: \`<topic> criticism\`, \`<topic> limitations\`, \`<topic> controversy\`

Use \`https://html.duckduckgo.com/html/?q=<query>\` for web searches (parse \`<a class="result__a">\` links and snippets).

### 3. Deep Reads (go deep)
For each sub-question, identify the 3–5 most relevant URLs. Fetch and read each one fully. Extract:
- Key claims and data points
- Author / publication / date (assess credibility)
- References to follow up on

### 4. Cross-Reference & Validate
- Note where sources agree and disagree.
- Flag claims from only one source as unverified.
- If numbers or stats are cited, trace to the primary source.
- Prefer sources from the last 2 years unless historical context is needed.

### 5. Synthesise & Report
\`\`\`
## Summary
2–3 sentence TL;DR.

## Background
Context needed to understand the topic.

## Key Findings
- Finding 1 (source: [title](url))
- Finding 2 ...

## Different Perspectives / Debate
Where experts or sources disagree, and why.

## Open Questions / Gaps
What is still unknown or contested.

## Sources
Numbered list of all URLs consulted, with title and date.
\`\`\`

## Tips
- Run at least 5 distinct searches before writing the report.
- Read at least 4 full pages (not just snippets).
- Never present a single source as definitive — always triangulate.
- Cite every factual claim with a link.`
  },

  {
    id: 'coding',
    name: 'Coding',
    description: 'Write, debug, refactor, explain, and review code in any programming language.',
    category: 'dev',
    icon: '💻',
    content: `---
name: coding
description: Write, debug, refactor, explain, and review code in any programming language
trigger: When the user asks to write code, fix a bug, refactor, explain how code works, review a function, add tests, or help with any programming task
category: dev
icon: 💻
enabled: true
---

# Coding Skill

Handle the full software development lifecycle: writing new code, understanding existing code, debugging, refactoring, and testing — in any language.

## Write New Code
- Confirm the language, framework, and environment before starting.
- Ask for constraints (performance, style guide, existing dependencies).
- Write clean, idiomatic code with comments for non-obvious logic.
- Include a usage example or short test block where helpful.

## Debug & Fix
1. Read the full error message and stack trace carefully.
2. Identify the exact file and line where the error originates.
3. Inspect surrounding code for logic errors, type mismatches, null-dereferences, or off-by-one errors.
4. Run the code in a terminal to reproduce the error if needed.
5. Apply the minimal fix that resolves the root cause — avoid masking errors with bare try/catch.
6. Explain what was wrong and why the fix works.

## Refactor
- Identify code smells: duplication, long functions, deep nesting, magic numbers, unclear naming.
- Refactor in small, safe steps — preserve behaviour before improving structure.
- Prefer readability over cleverness.
- Verify functionality is unchanged after refactoring.

## Explain Code
- Summarise what the code does at a high level first.
- Walk through it section by section, explaining intent not just mechanics.
- Highlight non-obvious patterns (closures, generators, recursion, bitwise tricks, etc.).
- Point out potential edge cases or bugs noticed during the read.

## Code Review
Evaluate on these dimensions and provide concrete, actionable feedback:
- **Correctness** — does it do what it's supposed to? Are edge cases handled?
- **Readability** — are names clear? Is logic easy to follow?
- **Performance** — any O(n²) loops, N+1 queries, or memory leaks?
- **Security** — injection risks, unvalidated input, exposed secrets, insecure defaults?
- **Tests** — adequate coverage? Are tests meaningful?

## Add Tests
- Identify the testing framework in use (Jest, pytest, Go test, etc.) or ask.
- Write unit tests for individual functions, edge cases, and failure paths.
- Aim for tests that are independent, deterministic, and fast.

## Quick-Run Commands
\`\`\`
python3 <file>.py          # Python
node <file>.js             # Node.js
npx ts-node <file>.ts      # TypeScript
go run <file>.go           # Go
cargo run                  # Rust
java <ClassName>.java      # Java 11+
swift <file>.swift         # Swift
ruby <file>.rb             # Ruby
\`\`\`

## Pre-Delivery Checklist
- No hardcoded secrets or credentials
- Input is validated / sanitised at entry points
- Error paths are handled (not silently swallowed)
- Async code uses proper await / error handling
- No unused imports or dead code left behind`
  },

  {
    id: 'csv-toolkit',
    name: 'CSV Toolkit',
    description: 'Inspect, clean, summarize, filter, and transform CSV and TSV files.',
    category: 'productivity',
    icon: '📊',
    content: `---
name: csv-toolkit
description: Inspect, clean, summarize, filter, and transform CSV and TSV files
category: productivity
icon: 📊
enabled: true
---

Work with local CSV or TSV data using lightweight shell tools.

Preferred tools:
- \`python3\` with the standard \`csv\` module for reliable parsing
- \`mlr\` (Miller) if installed for fast tabular summaries
- \`csvkit\` commands such as \`csvlook\`, \`csvcut\`, \`csvstat\`, \`csvgrep\` if installed

Workflow:
1. Detect delimiter and header structure from the file.
2. For quick inspection, show row count, column count, header names, and a 5-row preview.
3. For analysis requests, compute exactly what the user asked for: filtering, grouping, aggregations, sorting, or conversion to JSON or Markdown.
4. Save transformed output to a sibling file unless the user asked for inline output only.

Avoid naive comma-splitting because quoted fields can break it. If the file is large, sample first and then run the full transform once the operation is clear.`
  },

  {
    id: 'markdown-workbench',
    name: 'Markdown Workbench',
    description: 'Format, lint, outline, and convert Markdown notes and docs.',
    category: 'productivity',
    icon: '📝',
    content: `---
name: markdown-workbench
description: Format, lint, outline, and convert Markdown notes and docs
category: productivity
icon: 📝
enabled: true
---

Help turn rough notes into usable docs quickly.

Workflow:
1. Read the source Markdown or note file.
2. Decide whether the user needs cleanup and formatting, heading structure, summary or outline, checklist extraction, or conversion to HTML or PDF.
3. Preserve meaning while improving structure and readability.

Common tasks:
- Normalize headings, lists, code fences, and spacing
- Pull out tasks into a checklist grouped by topic or urgency
- Build a short linked outline from headings
- If available, use \`pandoc\` to convert Markdown to HTML, DOCX, or PDF

Prefer preserving the user's tone unless they ask for a rewrite.`
  },

  // ── MAKER ────────────────────────────────────────────────────────────────────
  {
    id: 'psa-car-controller',
    name: 'PSA Car Controller',
    description: 'Control and query a local psa_car_controller instance for vehicle status, charging, climate, locks, lights and trips.',
    category: 'maker',
    icon: '🚗',
    content: `---
name: psa-car-controller
description: Control and query a local psa_car_controller instance for vehicle status, charging, climate, locks, lights and trips
trigger: When the user asks about a Peugeot, Citroen, Opel, Vauxhall or DS vehicle connected through psa_car_controller, including status, charging, preconditioning, locks, horn, lights, trips, charging sessions, battery SOH or settings
category: maker
icon: 🚗
enabled: true
---

# PSA Car Controller

Use the local [flobz/psa_car_controller](https://github.com/flobz/psa_car_controller) HTTP API. Default base URL: \`http://localhost:5005\`. Only use another host if the user explicitly gives one.

## Request rules

- Use \`http_request\` when available; otherwise use \`curl\`.
- Default to JSON output and show the exact endpoint you called.
- If the user does not provide a VIN, call \`GET /settings\` first and infer it from the configured vehicle when possible. If there are multiple vehicles or no VIN is present, ask for the VIN.
- For read-only status requests, prefer cache when freshness is not important: \`GET /get_vehicleinfo/<VIN>?from_cache=1\`.
- For live status, use \`GET /get_vehicleinfo/<VIN>\`. If the user wants a refresh from the car first, call \`GET /wakeup/<VIN>\`, wait briefly, then fetch status.
- For state-changing actions that could be safety-sensitive (unlock, horn, lights, climate, charge stop/start), make sure the user intent is explicit before calling them.
- If changing settings via \`/settings/<section>\`, mention that the app needs a restart afterward.

## Supported endpoints

- Vehicle state: \`GET /get_vehicleinfo/<VIN>\`
- Cached vehicle state: \`GET /get_vehicleinfo/<VIN>?from_cache=1\`
- Wake up / refresh state: \`GET /wakeup/<VIN>\`
- Start or stop preconditioning: \`GET /preconditioning/<VIN>/1\` or \`/0\`
- Start or stop charge immediately: \`GET /charge_now/<VIN>/1\` or \`/0\`
- Set charge stop hour: \`GET /charge_control?vin=<VIN>&hour=<H>&minute=<M>\`
- Set charge threshold percentage: \`GET /charge_control?vin=<VIN>&percentage=<PERCENT>\`
- Set scheduled charge hour: \`GET /charge_hour?vin=<VIN>&hour=<H>&minute=<M>\`
- Honk horn: \`GET /horn/<VIN>/<COUNT>\`
- Flash lights: \`GET /lights/<VIN>/<DURATION>\`
- Lock or unlock doors: \`GET /lock_door/<VIN>/1\` or \`/0\`
- Battery SOH: \`GET /battery/soh/<VIN>\`
- Charging sessions: \`GET /vehicles/chargings\`
- Trips: \`GET /vehicles/trips\`
- Dashboard / root UI: \`GET /\`
- Read settings: \`GET /settings\`
- Update settings: \`GET /settings/<section>?key=value\`

## Response format

Reply with:
- action performed
- endpoint used
- status/result
- key fields from the JSON response
- any follow-up note, such as restart needed for settings changes

If the API returns an error, include the response body and suggest the next useful check, usually \`/settings\` or a VIN validation.`
  },

  {
    id: 'bambu-studio-cli',
    name: 'BambuStudio CLI',
    description: 'Slice 3MF/STL files, export G-code and slicing data using BambuStudio on the command line.',
    category: 'maker',
    icon: '🖨️',
    content: `---
name: bambu-studio-cli
description: Slice 3MF/STL files and export results using the BambuStudio command-line interface
category: maker
icon: 🖨️
enabled: true
---

# BambuStudio CLI

Invoke BambuStudio headlessly for slicing and exporting. The binary is typically \`bambu-studio\` on Linux/macOS or \`bambu-studio.exe\` on Windows.

## Core flags

| Flag | Description |
|------|-------------|
| \`--slice <plate>\` | Slice plates: \`0\` = all, \`N\` = plate N |
| \`--export-3mf <out.3mf>\` | Export sliced result as 3MF |
| \`--outputdir <dir>\` | Directory for all exported files |
| \`--load-settings "machine.json;process.json"\` | Override printer + process settings |
| \`--load-filaments "f1.json;f2.json"\` | Override filament settings (use \`;\` separators, skip slots with empty entry) |
| \`--curr-bed-type "Cool Plate"\` | Set bed type via command line |
| \`--arrange <0\|1>\` | Auto-arrange: 0=off, 1=on |
| \`--orient\` | Auto-orient models before slicing |
| \`--scale <factor>\` | Scale model by float factor (e.g. \`1.5\`) |
| \`--export-settings <out.json>\` | Dump merged settings to JSON |
| \`--export-slicedata <dir>\` | Export slicing data to folder |
| \`--load-slicedata <dir>\` | Load cached slicing data |
| \`--info\` | Print model info without slicing |
| \`--debug <0-5>\` | Log level: 0=fatal … 5=trace |
| \`--pipe <name>\` | Send progress to named pipe |
| \`--uptodate\` | Upgrade 3MF config values to latest profiles |
| \`--help\` | Show CLI help |

Setting priority (highest → lowest):
1. \`--key=value\` flags on the command line
2. Files loaded via \`--load-settings\` / \`--load-filaments\`
3. Settings embedded in the 3MF file

## Common usage patterns

### Slice a 3MF using its own settings
\`\`\`bash
bambu-studio --slice 0 --debug 2 --export-3mf output.3mf model.3mf
\`\`\`
Slices all plates in model.3mf and exports to output.3mf.

### Slice a 3MF with custom machine/process/filament overrides
\`\`\`bash
bambu-studio \\
  --load-settings "machine.json;process.json" \\
  --load-filaments "filament1.json;;filament3.json" \\
  --curr-bed-type "Cool Plate" \\
  --slice 2 --debug 2 \\
  --export-3mf output.3mf \\
  model.3mf
\`\`\`
Slices plate 2 only, overriding printer/process/filament settings from JSON files.
Empty \`;\;\` entries keep the filament slot from the 3MF unchanged.

### Slice raw STL files
\`\`\`bash
bambu-studio \\
  --orient --arrange 1 \\
  --load-settings "machine.json;process.json" \\
  --load-filaments "filament.json" \\
  --slice 0 --debug 2 \\
  --export-3mf output.3mf \\
  model.stl
\`\`\`
Auto-orients and arranges the STL, applies settings from JSON files, slices all plates.

## When the user asks to slice a file:
1. Confirm the path to \`bambu-studio\` binary (run \`which bambu-studio\` or ask the user)
2. Check if custom settings JSON files are needed or if the 3MF is self-contained
3. Build the command from the flags above
4. Run it and check for errors in the output (debug level 2 is a good default)
5. Report the output file location and any warnings`
  }
];

// ── Routes ─────────────────────────────────────────────────────────────────────

/** GET /api/store — return catalog with installed status */
router.get('/', (req, res) => {
  const fs = require('fs');
  const installed = new Set();

  if (fs.existsSync(SKILLS_DIR)) {
    for (const f of fs.readdirSync(SKILLS_DIR)) {
      installed.add(f.replace(/\.md$/i, ''));
    }
  }

  const items = CATALOG.map(s => ({
    id: s.id,
    name: s.name,
    description: s.description,
    category: s.category,
    icon: s.icon,
    installed: installed.has(s.id)
  }));

  res.json(items);
});

/** POST /api/store/:id/install — write the skill file */
router.post('/:id/install', (req, res) => {
  const fs = require('fs');
  const skill = CATALOG.find(s => s.id === req.params.id);
  if (!skill) return res.status(404).json({ error: 'Skill not found in catalog' });

  if (!fs.existsSync(SKILLS_DIR)) fs.mkdirSync(SKILLS_DIR, { recursive: true });

  const filePath = path.join(SKILLS_DIR, `${skill.id}.md`);
  fs.writeFileSync(filePath, skill.content, 'utf-8');

  // Also reload the skill runner if available
  const skillRunner = req.app.locals?.skillRunner;
  if (skillRunner) skillRunner.loadSkillFile(filePath);

  res.json({ success: true, id: skill.id, name: skill.name, filePath });
});

/** DELETE /api/store/:id/uninstall — remove the skill file */
router.delete('/:id/uninstall', (req, res) => {
  const fs = require('fs');
  const skill = CATALOG.find(s => s.id === req.params.id);
  if (!skill) return res.status(404).json({ error: 'Skill not found in catalog' });

  const filePath = path.join(SKILLS_DIR, `${skill.id}.md`);
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);

  res.json({ success: true, id: skill.id });
});

module.exports = router;
