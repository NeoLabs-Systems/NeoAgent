const express = require('express');
const router = express.Router();
const path = require('path');
const { requireAuth } = require('../middleware/auth');

router.use(requireAuth);

const SKILLS_DIR = path.join(__dirname, '../agent-data/skills');

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
