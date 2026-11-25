# NeoLabs → Go migration plan

Applies to all four NeoLabs apps: **NeoAgent** (first), NeoRouter, NeoCloud, NeoRecall.
Status: plan only, nothing implemented. Written 2026-11-24 against `beta` (NeoAgent v3.8.1-beta.49). Supersedes the earlier Rust draft: language decided as **Go** (§2).

---

## 1. Goal and scope

**Goal:** same features, same UI, same data, much lower CPU / RAM / disk / startup cost, and a codebase that is easier to maintain than today's 125k-line JS server. **No Node at runtime, at all.**

| Layer | Today | After |
|---|---|---|
| Backend server (`server/`) | Node.js + Express + better-sqlite3 | **Go** (net/http + chi, SQLite) |
| CLI / installer / updater (`bin/`, `lib/`, `runtime/`) | Node.js | **Go**, same binary (cobra) |
| Client (`flutter_app/`) | Flutter (web, Android, iOS, macOS, Windows, Linux) | **Unchanged** |
| Landing, docs (Docusaurus, dev tooling only), firmware (ESP32 C, Pi Python), NeoCloud Go lite client | – | Unchanged |

**Why the Flutter client stays:** the UI *is* the Flutter code, so keeping it is the only way the UI stays pixel-identical. Flutter already compiles to native code; the cost is the Node backend (V8 heap, 1.7 GB `node_modules` in NeoAgent, one Node process per shell session, Node inside every VM). "100% the same" therefore means: **the HTTP + socket/SSE API, on-disk data, CLI and release artifacts stay compatible**, and the unchanged clients behave identically.

The only Dart change: NeoAgent's local backend installer starts a Node executable today and will start the Go binary instead (§6.4). No widget, layout, theme, string or flow changes.

**Removed on purpose (decided 2026-11-24):**
- **Remotion** (NeoAgent social video): `server/services/ai/integrated_tools/remotion.js`, its entries in `ai/tools/definitions/index.js`, `ai/integrated_tools/index.js`, `ai/deliverables/workflows.js`, and the `remotion` / `@remotion/cli` dependencies. The model no longer sees the tool; UI entries that only exist for it are hidden via the existing capability flags, not redesigned.
- **Slidev** (NeoAgent slide decks): `ai/integrated_tools/slidev.js`, its registration in `ai/integrated_tools/index.js`, and the `@slidev/cli` / `@slidev/theme-default` dependencies.
- **WhatsApp call handling** (NeoAgent): the automatic rejection of incoming WhatsApp calls, because whatsmeow has no call support. Incoming calls just ring on the phone.
- **Discord voice receive** (NeoRecall Discord voice source bot): `@discordjs/voice`, `prism-media`, `opusscript`, the Discord voice source, and `discord.js` in NeoRecall (only used there). Other NeoRecall sources are unaffected.

---

## 2. Language decision: Go

Criteria you set: maintainability, speed, modularity, stability, with lower resource use as the original goal.

| Criterion | Why Go |
|---|---|
| Maintainability | Deliberately plain language that matches GUIDELINES ("readable over clever", "direct, boring code"); small surface for contributors to an AGPL project; the dynamic JSON in tool arguments and LLM payloads ports directly (`map[string]any`, `json.RawMessage`) instead of becoming heavy type machinery |
| Speed | Development: seconds-long compiles and fast tests make porting ~137k lines of JS realistic; goroutines map closely onto the current async flow. Runtime: all four apps are I/O-bound (LLM calls, SQLite, sockets); Go's runtime is far faster than Node there |
| Modularity | Packages with explicit interfaces at service seams; one shared module for the four apps; app code depends on interfaces, not on each other |
| Stability | Go 1 compatibility promise, conservative toolchain, mature stdlib (`net/http`, `crypto/*`, `database/sql`); `go vet`, `staticcheck`, race detector and fuzzing in CI |
| Ecosystem for our red items | **WhatsApp: `whatsmeow`, the reference implementation, native.** Official OpenAI / Anthropic / Google / MCP Go SDKs; mature `pkg/sftp`, `go-webauthn`, `chromedp`, `discordgo`, `slack-go` |
| Shared code | NeoCloud already has a ~27.8k-line Go sync client; NCB1 crypto and protocol code can be shared, not rewritten |
| Deployment | `CGO_ENABLED=0` static binaries for NeoAgent, NeoRouter and NeoCloud; trivial cross-compile; static guest agent for VMs |

**Costs accepted (and how they are handled):**
- Idle memory is above a no-GC language. Mitigation: `GOMEMLIMIT` + `GOGC` tuning, no per-session processes, benchmarked against Node in prep (targets in §8, not assumed).
- socket.io server for Go (`zishang520/socket.io`, v4) has a smaller community. It is the chosen library; interop with the Dart `socket_io_client` is proven by the websocket contract tests before the realtime layer is built on it.
- cgo is needed only by **NeoRecall** (SQLCipher, ONNX). NeoRecall is last in order; the other three stay pure Go.
- PDF signing needs custom glue in any language (§5.2).

---

## 3. Compatibility contract (what "same functionality" means)

The Go build must pass this before it replaces Node.

1. **HTTP** – every route, method, status, header, cookie, JSON body and error string. JSON byte-compatible where clients see it: key order (use ordered structs or an ordered-map type for responses whose key order matters), JS `toISOString()` dates (`2026-11-24T10:00:00.000Z`), `undefined`-omitted keys vs `null` (explicit `omitempty` rules). Go already prints floats in ES6 style (`3`, not `3.0`). Error envelopes, validation messages and rate-limit headers copied verbatim.
2. **Realtime** – socket.io events, payloads, rooms, handshake (NeoAgent, NeoCloud); raw WebSocket proxies (NeoAgent live voice and gateways, NeoRouter live voice and federation relay); SSE ids and `Last-Event-ID` resume (NeoRecall, NeoCloud handoff, NeoRouter streaming).
3. **Data** – the Go build opens an existing data dir unchanged: same SQLite file and schema, migration bookkeeping, FTS5 / vec tables, encryption formats, key files, and layout under `~/.<app>/`. Downgrade to the last Node release stays possible.
4. **CLI** – same commands, flags, exit codes, output and `--json` event stream (NeoAgent's setup contract generates `setup_contract.g.dart`).
5. **Behaviour** – scheduling, retries/backoff, rate limits, agent loop (NeoAgent harness eval), routing decisions (NeoRouter), search/transcription results (NeoRecall), sync results (NeoCloud).
6. **Other clients** – ESP32 wearable / smart panel / Pi appliance protocols and OTA manifests, NeoCloud's Go sync client, external OpenAI/Anthropic SDKs on NeoRouter, NeoRouter pool peers still on Node, third-party OAuth/MCP clients.

**How it is verified**
- Existing JS integration / API / contract / security / e2e / websocket suites get a base-URL mode and run black-box against both servers. Go must pass everything Node passes.
- Golden recordings: Flutter widget tests plus a scripted web click-through of every screen against Node through a recording proxy; replayed against Go and diffed (only ids, timestamps, nonces normalised).
- JS unit tests (they import internals) are ported to Go table tests alongside the packages they cover.
- Flutter tests and NeoCloud's Go e2e tests run unchanged against the Go server.
- Resource benchmarks (§8) run in CI.

---

## 4. Shared foundation: `neolabs-go`

New repo/module **`github.com/NeoLabs-Systems/neolabs-go`** (tagged releases, imported by each app). Strict package boundaries: no package imports an app; apps depend on interfaces; no global state; one DB owner per process.

| Package | Replaces | Contents |
|---|---|---|
| `runtimecfg` | `runtime/*.js` | data dir, `.env` (`godotenv`), release channels, update check |
| `db` | `server/db/database.js`, migration runners | SQLite open (WAL, `synchronous=FULL`, FKs), single writer discipline, migration runner keeping each app's existing version table / ids; pure-Go `modernc.org/sqlite` (FTS5 included); cgo build tag for SQLCipher + sqlite-vec (NeoRecall) |
| `httpx` | `server/http/*`, helmet, cors, compression, rate limit | chi router builder, security headers/CSP identical to helmet config, CORS, compression, sliding-window limiter, error envelope, request-id, cancel-on-disconnect (`context`), Flutter web serving (SPA fallback, cache rules, `index.html` rewrites), `/_neolabs/analytics.js` |
| `auth` | bcrypt, otplib, simplewebauthn, session stores, tokens | `x/crypto/bcrypt` (existing `$2b$` hashes), `pquerna/otp` + recovery codes, `go-webauthn` (existing credential records), express-session-compatible cookies (`s:<id>.<HMAC-SHA256 b64>`) and `sessions` table, opaque bearer tokens, OAuth2 server pieces |
| `realtime` | socket.io, SSE | socket.io v4 server (library or in-house fallback, §2), SSE with outbox resume, raw WebSocket helpers (`coder/websocket`) |
| `llm` | per-app provider code | thin layer over the **official OpenAI, Anthropic and Google Go SDKs** plus a small OpenAI-compatible client for NIM / Nous / OpenRouter / Ollama / custom; shared tool-call types, retries, error mapping |
| `cryptox` | secrets/keys/stream-cipher code | AES-256-GCM sealed values in each app's layout, HKDF, X25519/Ed25519 (stdlib), byte-compat vectors generated from Node |
| `ml` | transformers.js, sherpa-onnx | ONNX runtime + tokenizers wrappers with numeric parity tests (cgo, NeoRouter/NeoRecall only) |
| `pdf` | pdf-lib, fontkit, @signpdf, node-forge | see §5.2 |
| `cli` | `lib/manager.js`, `lib/cli/*` | common CLI shape (cobra), service install via `kardianos/service` (launchd / systemd-user / Windows), terminal UI |
| `analytics` | Countly code | same events and payloads |
| `testkit` | test helpers | black-box runner, golden diff, temp data dirs (never the real `~/.<app>`) |

Lint/quality gates in every repo: `go vet`, `staticcheck`/`golangci-lint`, `go test -race`, fuzz targets for parsers (multipart, ingest headers, WebDAV XML, PDF input), `govulncheck`, pinned `go.sum`, `CGO_ENABLED=0` build check for the pure-Go apps.

---

## 5. Dependency replacements

### 5.1 WhatsApp: baileys → `whatsmeow`

**Choice: [`go.mau.fi/whatsmeow`](https://github.com/tulir/whatsmeow)** (the Go WhatsApp Web multi-device library behind mautrix-whatsapp and others; actively updated; no tagged releases, so the version is pinned by commit and bumped deliberately). Native Go, no FFI, no sidecar.

Mapping of NeoAgent's actual baileys surface (`services/messaging/whatsapp.js`, `services/integrations/whatsapp/provider.js`):

| baileys usage | whatsmeow |
|---|---|
| `makeWASocket`, `useMultiFileAuthState`, `creds.update` | `whatsmeow.NewClient` + `sqlstore` device store inside the NeoAgent data dir |
| `connection.update` (QR, open/close, logout, reconnect) | `GetQRChannel`, `Connected` / `Disconnected` / `LoggedOut` events, auto-reconnect; QR string for the existing Flutter QR screen |
| `messages.upsert`, `downloadMediaMessage` | `events.Message`, `Download` |
| `sendMessage` (text, media, replies) | `SendMessage`, `Upload` |
| `readMessages`, `sendPresenceUpdate` | `MarkRead`, `SendChatPresence` |
| `group-participants.update`, `groupFetchAllParticipating` | `events.GroupInfo`, `GetJoinedGroups` |
| `messaging-history.set`, `chats.upsert`, `chats.update` | `events.HistorySync`, app-state events |
| `logout`, `end` | `Logout`, `Disconnect` |

**Keeping existing linked sessions:** baileys stores `creds.json` (noise key, identity key, signed pre-key, registration id, ADV secret, account) plus `pre-key-*`, `session-*`, `sender-key-*`, `app-state-sync-key-*` files. whatsmeow's `Device` holds the same primitives. NeoAgent gets a one-time **converter** that reads each baileys auth dir and writes the whatsmeow store, leaving the original folder untouched until the account has connected once. Whether WhatsApp accepts a converted session is proven on a test account during verification.

**Verification:** a test account linked via baileys is converted and must receive/send text, media, group messages, typing and read receipts without re-pairing; history sync compared to baileys for the same account.

### 5.2 PDF signing (NeoCloud): pdf-lib + @signpdf + node-forge → `neolabs-go/pdf`

**What NeoCloud uses today** (`server/services/signing/pdf/*`, `seal.js`): load/create documents, add pages, AcroForm `getForm` + `updateFieldAppearances` + `flatten`, draw text/line/rectangle/circle/image, embed fonts (fontkit subsetting) and PNG/JPG, embedded attachments, metadata setters, deterministic `save`; `@signpdf` placeholder + PKCS#7 detached seal (`adbe.pkcs7.detached`); `node-forge` self-signed P12 (CN "NeoCloud document seal").

No single Go library covers all of this with an open licence (UniPDF does but is commercial; pdfcpu inspects/removes signatures but did not show signing or flattening; `digitorus/pdfsign` signs but calls itself in development). So `neolabs-go/pdf` is a **small internal package composed of focused open-source parts plus our own incremental-update code**:

| Job | Approach |
|---|---|
| Load / inspect, attachments, metadata | `pdfcpu` (Apache-2.0) where it fits, own object-level reader for what it lacks |
| Drawing text / shapes / images, font embedding and subsetting | write content-stream operators directly, `signintech/gopdf`-style TTF embedding or `golang.org/x/image/font/sfnt` for metrics |
| Form appearances and flattening | generate appearance streams and draw them into page content ourselves (the same technique pdf-lib's `flatten` uses); PDFium (via a Go binding) is used in tests and as an option if the corpus shows gaps; to be proven on the corpus |
| Signature dictionary, ByteRange / Contents placeholder | own incremental update writer, same SubFilter as today |
| PKCS#7 / CMS detached signature | `go.mozilla.org/pkcs7`-style signer or `smallstep/pkcs7`, plus stdlib `crypto/rsa`, `crypto/x509` |
| Self-signed certificate + P12 | stdlib `crypto/x509` + `software.sslmate.com/src/go-pkcs12` |

**Parity rule (pdf-lib bytes cannot be reproduced by any other library, so the contract is defined by result):**
- every finalised PDF validates as signed and unmodified in Adobe Acrobat, poppler `pdfsig` and pyHanko;
- rendered pages (150 dpi) match the Node output within a small pixel tolerance on a fixed corpus of NeoCloud test documents (forms, images, fonts, multi-party flows);
- field names and values, attachments, metadata identical;
- output stays **deterministic** (same input → same bytes);
- already-signed documents are stored blobs and are never rewritten.

This is the least certain item in the plan, so it is built and validated against the corpus first in NeoCloud's migration (§7.2).

### 5.3 Full mapping

| npm package | Apps | Go |
|---|---|---|
| express, cors, helmet, compression, express-rate-limit, multer | all | `net/http` + chi, own middleware, `mime/multipart` (same limits and error codes, e.g. multer `LIMIT_FILE_SIZE` → 413) |
| better-sqlite3 | all | `modernc.org/sqlite` (pure Go) |
| better-sqlite3-multiple-ciphers | NeoRecall | SQLCipher via cgo if the cipher config matches, else SQLite3MultipleCiphers build (checked first in NeoRecall prep) |
| sqlite-vec | NeoRecall | official sqlite-vec Go bindings (cgo or wasm), same version 0.1.9 |
| express-session + sqlite store | NeoAgent, NeoCloud | `auth` session store on the same table |
| bcrypt, otplib, @simplewebauthn/server, qrcode | all | `x/crypto/bcrypt`, `pquerna/otp`, `go-webauthn/webauthn`, `skip2/go-qrcode` |
| socket.io, ws | NeoAgent, NeoCloud / NeoRouter | `zishang520/socket.io` or in-house layer (§2), `coder/websocket` |
| node-cron | NeoAgent | `robfig/cron` (seconds field, timezones) |
| openai, @anthropic-ai/sdk, @google/genai | NeoAgent, NeoRouter, NeoRecall, NeoCloud | official Go SDKs via `llm` |
| @modelcontextprotocol/sdk | NeoAgent, NeoRecall | official `modelcontextprotocol/go-sdk` |
| zod | NeoRecall, NeoRouter | struct tags + validators that produce zod `flatten()`-shaped errors |
| googleapis | NeoAgent | official `google.golang.org/api` |
| imapflow, mailparser, nodemailer | NeoAgent, NeoCloud | `emersion/go-imap` + `go-message`, `wneessen/go-mail` |
| ical.js | NeoAgent | `arran4/golang-ical` |
| cheerio | NeoAgent | `PuerkitoBio/goquery` |
| telegraf | NeoAgent | `go-telegram/bot` |
| discord.js (text only) | NeoAgent | `bwmarrin/discordgo` |
| Slack, GitHub clients | NeoAgent | `slack-go/slack`, `google/go-github` |
| **baileys** | NeoAgent | **whatsmeow** (§5.1) |
| playwright-chromium | NeoAgent | `chromedp` (CDP); browser-tool operations re-implemented with Playwright's auto-wait semantics (playwright-go is avoided because it bundles a Node driver) |
| sharp | NeoAgent, NeoCloud | `disintegration/imaging` / `x/image` (pure Go); HEIC through the `heif-convert`/ffmpeg subprocess to keep cgo out |
| tesseract.js | NeoAgent | `tesseract` binary as subprocess with the same `eng/deu.traineddata` |
| geoip-lite | NeoAgent | reader for geoip-lite's data files (same lookups) |
| bonjour-service | NeoAgent | `grandcat/zeroconf` |
| proper-lockfile, json5, yaml, dotenv, uuid | all | `gofrs/flock`, a json5 parser, `yaml.v3`, `godotenv`, `google/uuid` |
| @gcu/iso9660 | NeoAgent | `kdomanski/iso9660` |
| @novnc/novnc | NeoAgent | static assets served as-is |
| @bitwarden/cli | NeoAgent | keep invoking the `bw` binary |
| **remotion, @remotion/cli** | NeoAgent | **removed** |
| **@slidev/cli, @slidev/theme-default** | NeoAgent | **removed** |
| undici, socks | NeoRouter | `net/http` transport + `x/net/proxy` |
| node:crypto X25519/Ed25519/HKDF, SPKI | NeoRouter | stdlib `crypto/ecdh`, `crypto/ed25519`, `crypto/hkdf`, `crypto/x509` (interop-tested with Node peers) |
| @huggingface/transformers | NeoRouter, NeoRecall | `ml` (`onnxruntime_go` + tokenizers via cgo), numeric parity with stored vectors |
| sherpa-onnx-node | NeoRecall | sherpa-onnx's Go API (cgo), or the same ONNX models on `onnxruntime_go`; to be confirmed in NeoRecall prep |
| ffmpeg-static, llama-server, LibreOffice `soffice` | NeoRecall, NeoRouter, NeoCloud | keep as subprocesses (ship static ffmpeg) |
| **@discordjs/voice, prism-media, opusscript, discord.js** | NeoRecall | **removed** |
| mammoth, pdf-parse | NeoRecall | docx unzip + XML text walk, PDF text extraction; parity = same search/ask results on a corpus |
| libsodium-wrappers | NeoRecall | `x/crypto/nacl` / stdlib (same primitives) |
| @aws-sdk/client-s3, lib-storage | NeoCloud | `aws-sdk-go-v2` |
| ssh2-sftp-client | NeoCloud | `x/crypto/ssh` + `pkg/sftp` (mature) |
| archiver, yauzl | NeoCloud | `archive/zip` |
| unpdf | NeoCloud | PDF text extraction in `neolabs-go/pdf` |
| **pdf-lib, fontkit, @signpdf/\*, node-forge** | NeoCloud | **`neolabs-go/pdf`** (§5.2) |

### 5.4 Node after the migration

None. No app ships, installs or spawns Node. (The agent can still run user-requested Node tools inside its VM like any other program; that is the user's environment, not NeoAgent's runtime.)

---

## 6. NeoAgent (first app)

### 6.1 Inventory

| Area | Facts |
|---|---|
| `server/` JS | ~125,800 lines (excluding `server/public`) |
| `lib/` (CLI, installer, schema migrations, OpenClaw/Hermes importers, QEMU install/signing) | ~11,100 lines; `runtime/` ~680 |
| Routes | 35 route files, ~341 router endpoints + ~27 app-level |
| Schema | ~98 `CREATE TABLE` (`lib/schema_migrations.js`, `server/db/database.js`), FTS5 |
| Realtime | socket.io, ~66 server→client and ~21 client→server events; raw `ws` for wearable, display, desktop gateways, Gemini/OpenAI live voice |
| Sessions | express-session, cookie `neoagent.sid`, SQLite store, rolling, `sameSite=lax` |
| Subprocesses | docker, qemu, tar, ffmpeg, Xvfb, git, hdiutil/diskutil/codesign, sudo, `shell_worker.js` (one Node process per shell) |
| Guest agent | `server/guest_agent.js` (~1,200 lines) runs inside the VMs with its own Node + express |
| Largest services (lines) | ai 30.1k · integrations 18.2k · messaging 9.2k · memory 6.5k · runtime 6.4k · tasks 5.2k · account 3.8k · voice 3.4k · behavior 2.5k · browser 2.5k · + 25 smaller |
| Tests | 260 backend unit, 12 integration, 7 security, 4 websocket, 3 e2e, 1 contract, 7 harness-eval, 52 Flutter (~51k lines JS tests) |
| Measured | `node_modules` 1.7 GB; local server RSS ~55 MB + ~4 MB per `shell_worker` (macOS; Linux baseline measured in prep) |

### 6.2 Layout

Lives under `go/` in this repo: `go/neolabs` (the shared module, moved to its own repo once stable) and `go/neoagent`, tied together by `go/go.work`.

```
go.work / go.mod
cmd/
  neoagent/                single binary: server + CLI subcommands
  neoagent-guest/          static binary for VM images (replaces guest_agent.js)
internal/
  db/                      schema, migrations, queries
  ai/                      engine loop, tools, compaction, model router
  integrations/            OAuth + provider clients (one package per provider)
  messaging/               Telegram, Discord, Slack, GitHub, WhatsApp (whatsmeow)
  runtime/                 QEMU/Docker VMs, display gateway, browser (CDP), desktop, android
  voice/                   live voice, transcription, wearable gateway
  http/                    routes (one file per domain, as today) → services
server/services/ai/prompts/  kept as files, embedded byte-identical (go:embed)
flutter_app/ landing/ docs/ firmware/   unchanged
```

The existing routes → services → utils separation is kept (routes handle HTTP only, services own logic, utils are pure). `server/`, `lib/`, `bin/`, `runtime/` (JS) and `node_modules` are deleted in the release. `GUIDELINES.md`, `AGENTS.md`, `CLAUDE.md` are rewritten for Go (package layout mirroring routes/services/utils, one DB owner, parameterised SQL only, errors wrapped with `%w`, `context` on every request path, no goroutine without an owner).

### 6.3 The migration (one pass)

**Prepare (on the Node codebase)**
- Base-URL mode for integration/security/contract/e2e/websocket suites; route + socket inventory; golden recordings of every Flutter screen.
- Early checks: socket.io server against the Dart `socket_io_client` (connect, event, ack, reconnect, rooms), and `modernc` SQLite opening a copy of the real DB and running the FTS5 queries identically.
- Snapshot of every tool definition JSON and assembled system prompt from Node (the model must see byte-identical schemas and prompts, minus the removed Remotion and Slidev tools).
- Freeze on-disk formats: schema dump, `integrations/secrets.js` AES-256-GCM layout, credential vault, baileys auth dirs, browser profiles, computer-runtime dirs.
- Baseline benchmarks on Linux and macOS.
- Remove Remotion and Slidev from the Node codebase first (small separate change), so both implementations are compared without them.

**Build** (one branch, this order)
1. `neolabs-go` platform packages; server boot, static/Flutter web serving, sessions (`neoagent.sid`), auth, account (geoip, passkeys, TOTP), setup, settings, security, admin, public status, access, analytics; migrations runner taking over `runSchemaMigrations()` + `VERSIONED_MIGRATIONS` with the same ids; socket.io.
2. Data domains: memory (FTS5 queries ported verbatim), tasks + scheduler, triggers, task webhooks, artifacts, web shares, timeline, files, workspace, skills, agent profiles, behavior, teach, health, commands.
3. AI core: all providers (OpenAI, OpenAI-compatible incl. NVIDIA NIM / Nous / OpenRouter / Ollama, Anthropic, Google, Grok + OAuth, GitHub Copilot, OpenAI Codex, Claude Code, NeoRouter, System One); engine loop, loop policy, run context/actions/ledger, `commitDelivery`, tool runner/selector/retrieval/salvage, repetition guard, compaction, history, model router/health/grants/visibility, rate limits, usage, output sanitizer, deliverables, hooks. Project rules unchanged: one model, one loop, no pre/post LLM passes, progress-based guards, model-authored user text.
4. Integrations and messaging: OAuth, connection store, secrets, Google, Microsoft, GitHub, Slack, Notion, Figma, Trello, Spotify, Nextcloud, DAV, email, Home Assistant, weather, news, phone, Tailscale, Bitwarden, NeoCloud, NeoRecall; messaging manager, inbound queue, approvals, shared routes; Telegram, Discord, Slack, GitHub, **WhatsApp on whatsmeow with the baileys session converter**; MCP (official Go SDK), OpenClaw/Hermes importers, social reach, social video (minus Remotion; no slides tool).
5. Voice, devices, computer runtime: live voice, voice notes, transcription, call coordinator, wearable gateway incl. OTA manifest paging, mobile health/device sync, Android widget endpoints; QEMU VM manager (same qemu calls, macOS signing), guest images with the Go guest agent (no Node in VMs), ISO builder, display/desktop gateways, browser (chromedp, existing profiles), android (adb), streaming hub; shells as in-process PTY sessions (`creack/pty`).
6. CLI and release: `neoagent` subcommands with identical commands/flags/output/`--json`; Go generator for the same `setup_contract.g.dart`; `install.sh` downloads a signed prebuilt binary; launchd/systemd point at it; distroless Docker image (+ qemu where needed); signed binary releases for linux x86_64/aarch64, macOS arm64/x86_64, Windows x86_64; self-update and `main`/`beta` channels on binaries (semantic-release kept for versioning).

**Verify** – contract green; harness eval ≥ Node on every case; live runs on Gemini, NVIDIA NIM (prod), one OpenAI-compatible and one Anthropic model; WhatsApp migration test (§5.1); ramfb VM test; wearable firmware requests replayed; OpenClaw/Hermes import on the `migtest` Lima VM; `-race` clean; benchmarks meet §8; dogfood on agent.neolabs.space with a data copy.

**Release** – major version, Node removed, release notes: same data dir, WhatsApp stays linked, rollback = reinstall previous version.

**Keeping up with `beta` during the build:** feature work continues in JS. Every change merged to `beta` after the inventory snapshot is tracked in a checklist on the `go` branch and ported before release; the contract suites catch anything missed. No schema change lands in JS without its Go migration in the same week.

### 6.4 Flutter impact

No UI changes. The local backend installer (`runtime_release_service.dart`, `runtime_activation_service.dart`, `local_backend_installer_io.dart`, `local_runtime_manager.dart`) keeps the signed `neoagent-runtime-manifest-*.json`, but activation runs the `neoagent` binary instead of `nodeExecutable` + `server/index.js`. Older app versions keep using older manifests.

### 6.5 Risks

| Risk | Handling |
|---|---|
| Agent behaviour drift | prompt/tool-schema byte snapshots, harness eval gate, comparison of the exact provider request bodies Node vs Go for recorded runs |
| socket.io library gap with the Dart client | websocket contract tests before building on it; patch the library where needed |
| WhatsApp session conversion | proven on a test account; whatsmeow bumps pinned and reviewed |
| Playwright semantics | port only operations the browser tools use; browser tool tests + recorded sessions |
| Goroutine leaks / data races | every goroutine has an owner and a `context`; `-race` in CI; leak checks in integration tests |
| `beta` keeps moving | post-snapshot change checklist; contract suites |
| Tests migrate the real `~/.neoagent` DB | `testkit` uses temp dirs or copies only |

---

## 7. The other three apps (same method, same module)

Order after NeoAgent: **NeoRouter → NeoCloud → NeoRecall.** NeoRouter reuses `llm` and gains most per request; NeoCloud reuses NeoAgent's session and socket.io layers, shares Go code with its existing sync client, and is still in development; NeoRecall carries the most data risk (encrypted DB, stored embeddings and voiceprints, cgo) and goes last when every shared package is proven. The NeoCloud signing check and the NeoRecall encryption/ML checks run early, in parallel with NeoAgent, because they decide feasibility.

### 7.1 NeoRouter

| Area | Facts |
|---|---|
| Size | `server/` ~30.3k, `lib/` ~3.0k, `runtime/` ~540 |
| DB | better-sqlite3, WAL, `synchronous=FULL`, `busy_timeout=10000`; 41 JS-function migrations (`schema_migrations`), ~36 tables, ISO timestamps via `strftime('%Y-%m-%dT%H:%M:%fZ')` |
| Auth | `Bearer nrs_…` dashboard sessions, `nrt_…` gateway keys via `Authorization` / `x-api-key` / `x-goog-api-key`; bcrypt 12, TOTP; secrets AES-256-GCM `iv|tag|ct` under `secret.key`; OAuth server (device code) + outbound OAuth (Codex, Nous, OpenRouter) |
| Realtime | no socket.io; `ws` live-voice passthrough (`/v1/live/sessions`, `/v1/realtime`, Gemini `BidiGenerateContent`), federation relay `/federation/v1/relay`; SSE streaming |
| Hot path | `/v1/chat/completions`, `/v1/messages` (+ `count_tokens`), `/v1/responses`, models, embeddings, images, audio, moderations, search, weather, videos, media; canonical format + two-way translators for 3 dialects; ~15 adapters; first chunks buffered before headers commit; 120 s idle timeout; trailing `: neorouter {json}`; streaming PII restorer |
| Routing | `RoutingPlan` scoring (intelligence/speed/cost, task classifier, EWMA stats, quota, budget pacing, cache affinity, plan slots, pool peers); hedged attempts (3× TTFT, 2.5–30 s), queueing, fallback |
| Federation | X25519 + HKDF + AES-GCM relay seal, Ed25519 identities, SPKI keys |
| Local ML | transformers.js worker (privacy NER, embeddings, speech), `llama-server`, ffmpeg |
| Client contract | Flutter at `/app/`, ~114 `/api/v1` calls, `X-NeoRouter-Space`, errors `{error:{code,message}}`; gateway headers `X-NeoRouter-*`, rate-limit headers, `Retry-After` |
| Tests | 45 API, 36 unit, `test/support/mock_provider.js` (reused unchanged as test upstream) |

Build order: platform (auth, keys, accounts, teams, settings, OAuth) → catalog, quota, budget, usage, providers, proxies (same SSRF guard and manual redirects) → gateway (translators, adapters, restorer, executor, `RoutingPlan` with every constant, checked against Node-generated decision tables: same inputs + stored stats → same model and trail) → live voice, federation (Go ↔ Node peer interop both directions), PII shield, compression → local ML on `ml` → CLI (`providers`, `reset-2fa`, `backup`, `rebuild-web`, …). JS migrations frozen to SQL with the current schema as baseline; Express quirks (`/models/:model(*)`, `INVALID_JSON`, `BODY_TOO_LARGE`, unclaimed WS upgrades closed) reproduced. Streaming proxy uses `http.Flusher` with a flush on every chunk, one goroutine per stream, `context` cancelled on client disconnect.

### 7.2 NeoCloud

| Area | Facts |
|---|---|
| Size | `server/` ~41.1k (signing ~8k, ai ~6.6k), `lib/` ~2.5k, `runtime/` ~250 |
| DB | better-sqlite3 13 (SQLite 3.53), WAL; 32 versions via `PRAGMA user_version`, pre-migration backup; ~70 tables + contentless FTS5 (`contentless_delete=1`) + triggers |
| Auth | `neocloud.sid` session (rolling 30 d), device Bearer tokens, WebDAV Basic + app passwords, OAuth2 + PKCE, bcrypt, TOTP, WebAuthn, QR login, device-code pairing; WOPI tokens and share proofs HMAC'd from `SESSION_SECRET` |
| Realtime | socket.io 4 (rooms `user:<id>`, `session:<hash>`; `files:changed`, `shares:changed`, `comments:changed`, `imports:changed`, `ai:suggestions`, `devices:*`, `signing:*`, `handoff:*`), websocket-only transport; SSE `/api/handoff/events` |
| Crypto (byte-identical) | `NEOCLOUD_MASTER_KEY` → HKDF-SHA256 (`neocloud:dek-wrap` / `:secrets` / `:backup`); per-user DEK `"v1:"+b64(iv|tag|ct)` AAD `user:<id>`; `"enc:v1:"` secrets; **NCB1** stream format (20-byte header, 64 KiB segments + tag, per-blob HKDF key, nonce prefix ‖ u32 index, AAD header ‖ index ‖ last-flag) for blobs, previews, upload parts, backups; NCV1 client vaults (server stores ciphertext only) |
| Storage/transfer | `storage/blobs/<uid>/<id[0..2]>/<uuid>`; single `PUT /api/upload` and resumable 8 MiB parts; etag = plaintext sha256; Range; sync snapshot + change journal; WebDAV (Nextcloud-compatible, LOCK, `oc:` props); WOPI/Collabora |
| Heavy parts | thumbnails (WebP 256/1024/320 sq), `soffice`, text extraction, **signing engine** (§5.2), S3/SFTP/WebDAV backups and mounts, streaming zip, 9 AI providers, mail outbox |
| Other client | Go lite sync client (~27.8k lines); its `clients/lite/e2e` tests are a ready black-box contract suite, and its crypto code can be shared with the server |
| Tests | 87 `node:test` files / ~723 tests (need base-URL mode), 5 Go e2e, 59 Go unit, 53 Flutter |

Build order: **signing check first** (can the §5.2 package pass the parity corpus?) and crypto (NCB1, DEKs, `enc:v1`, backup snapshots – Node and Go must read each other's output, shared with the lite client) → web serving (`index.html` rewrite, cookie-notice/analytics injection, no-store rules, strict CSP on `/app/sign*`, `/s/:token`) → sessions/auth/devices/OAuth/WebAuthn, socket.io + SSE → files, storage, transfer, sync, trash/versions, shares, comments, notes, activity, search (contentless FTS5) → WebDAV + WOPI (tested with Finder, Windows Explorer, Office, Nextcloud clients, the Go client) → previews, photos, duplicates, import, handoff, external storage, backup → AI organizer → **signing on `neolabs-go/pdf`** → CLI (backup verify/restore/migrate-storage-class, keys export, update + rollback, schtasks on Windows).

### 7.3 NeoRecall

| Area | Facts |
|---|---|
| Size | `server/` ~23.9k, `lib/` ~3.2k, `runtime/` ~560 |
| Processes | supervisor → `http` + `worker` → `inference_host`; Go: one process, goroutines + a bounded worker pool for inference |
| DB | **encrypted** SQLite (better-sqlite3-multiple-ciphers, key from `secret.key`), WAL, `synchronous=FULL`, sqlite-vec 0.1.9 + FTS5; 37 migrations, ~73 tables |
| Auth | `nrs_` bearer tokens (sha256), API keys, scoped OAuth tokens; bcrypt 12, TOTP + recovery codes, passkeys; full OAuth 2 authorization server; MCP JSON-RPC endpoint |
| Realtime / jobs | SSE `/api/v1/events` from `event_outbox`; SQLite job queue, 1-minute tick, 15 handlers |
| Heavy parts | ONNX models (silero-vad, pyannote seg 3.0 int8, WeSpeaker CAM++, multilingual-e5-small); ffmpeg; Deepgram/AssemblyAI/OpenAI STT |
| Client contract | ~55 `/api/v1` paths, web at `/app/`; `{error:{code,message,details?,requestId}}` with zod `flatten()` details; 2000 req / 5 min; chunked ingest headers (`X-Audio-*`, `X-Chunk-*`, `X-Final-Chunk`, …), resumable import (`Content-Range`, `X-Part-Sha256`), `Idempotency-Key` |
| Devices | Pi Zero 2 W desk appliance, ESP32-S3 smart panel (both unchanged, both pin the ingest protocol) |
| Removed | Discord voice source (§1) |
| Tests | 66 unit, 30 API, 15 integration |

Build order: encrypted DB access with cgo SQLCipher + sqlite-vec (open a real encrypted DB; decrypt `NRF1` sealed files and `NRB1` backups) → auth, OAuth server, MCP → recordings, conversations, transcripts, memories, settings, usage, audit → ingest + job queue + handlers → ML on `ml` with a parity gate (e5 embeddings reproduce stored vectors within 1e-5 cosine; WeSpeaker voiceprints likewise; VAD/diarization compared on a fixed audio corpus) → cloud sinks (WebDAV, Nextcloud, NeoCloud), Plaud/Memoket, document text extraction → CLI (backup/restore/reset-password/doctor). NeoRecall is the only app whose release build uses cgo (per-platform CI runners instead of pure cross-compile).

---

## 8. Resource targets

Measured on the same machine and data (Linux x86_64, macOS arm64), reported in CI. Targets are goals to be confirmed by the prep baselines, not promises.

| Metric | Node today | Target |
|---|---|---|
| Idle RSS (server) | measured in prep | ≤ 50% of Node, with `GOMEMLIMIT` set |
| RSS under load (agent run / gateway streams / ingest / sync) | measured | ≤ 60% of Node |
| Extra processes | Node per shell, supervisor + workers (NeoRecall), Node in each VM, transformers.js worker | none (in-process); only external tools (qemu, ffmpeg, soffice, llama-server, bw, tesseract) |
| Cold start to `/health` | measured | < 500 ms (excluding VM/model warm-up) |
| Install footprint | 1.7 GB `node_modules` (NeoAgent) + Node | single binary ~30–60 MB (+ models where used) |
| Docker image | Node base + deps | distroless + required tools |
| p95 latency, top 20 endpoints | measured | ≤ Node |

---

## 9. One security baseline, shared by all four apps

The four Node repos grew the same protections by copy-and-adapt, with small differences. In Go each protection lives once in `neolabs-go` and every app uses it. Wire formats stay as they are today (cookie names, token prefixes, sealed-value layouts) so nothing breaks for existing users; only the *implementation* is shared.

| Area | Baseline (implemented in `neolabs-go` unless marked later) |
|---|---|
| Response headers | CSP built per app from an ordered policy, `X-Content-Type-Options`, `X-Frame-Options`, CORP, Referrer-Policy, HSTS on HTTPS, and a **Permissions-Policy that is actually sent** (the Node servers configured it but helmet ignored the option) |
| Browser requests | CORS allow-list that defaults to loopback only; origin/referer guard on every state-changing `/api` call; `/API/...` case guard; `no-store` on API responses; body size limits |
| Sessions | HMAC-signed cookie, `HttpOnly`, `SameSite=Lax`, `Secure` on HTTPS and never sent over plain HTTP, rolling expiry, id regeneration on login, `DestroyForUser` to end every session of an account |
| Credentials | bcrypt cost 12 (existing hashes keep working, 72-byte rule preserved), TOTP and WebAuthn (later), bearer tokens stored only as SHA-256 digests, constant-time comparison everywhere |
| Secrets at rest | AES-256-GCM sealed values, tamper-evident; data dirs 0700, database and key files 0600; production refuses a missing or placeholder `SESSION_SECRET`; a separate encryption key so rotating the session secret does not lock stored credentials |
| Rate limiting | fixed-window limiter with draft-6 `RateLimit-*` and `Retry-After`, per route group |
| Outbound requests | `ssrf` client for every user-influenced fetch (web fetch, webhooks, custom provider base URLs, WebDAV/SFTP/S3 endpoints, NeoRouter providers): public IPs only, checked at dial time against DNS rebinding, redirects re-validated, proxy environment ignored |
| Database | WAL, foreign keys on, `synchronous=FULL`, one serialised writer, read-only reader pool, a database newer than the binary is refused |
| Server | `ReadHeaderTimeout` against slowloris, header size cap, panic recovery that never leaks internals, graceful shutdown |
| Supply chain and CI | pinned `go.sum`, `govulncheck`, `go vet`, `staticcheck`, `go test -race`, fuzzing for parsers, `CGO_ENABLED=0` for the pure-Go apps |

**Per-app alignment** (what is made identical when each app moves over):
- **NeoAgent, NeoCloud:** cookie sessions on the same `sessionx` store (`neoagent.sid`, `neocloud.sid`).
- **NeoRouter, NeoRecall:** `nrs_` / `nrt_` bearer tokens move onto the same digest-and-compare helpers; a shared `bearer` package (later) replaces the two separate middlewares.
- **Sealed values:** NeoAgent's `enc:v1:` layout is in `secretbox`; NeoCloud's `v1:`/`enc:v1:` layouts with AAD and NeoRouter's `iv|tag|ct` base64url layout become layouts of the same package, each verified against Node-produced vectors before use.
- **Login throttling, audit log, passkeys, TOTP:** one implementation each in `auth` (later), used by all four.

---

## 10. Progress

Started 2026-11-24. The shared module lives in its own repo, [NeoLabs-Systems/neolabs-go](https://github.com/NeoLabs-Systems/neolabs-go) (private for now; v0.1.0 and v0.2.0 are pushed). NeoAgent's Go code is in `go/neoagent`. **Everything after the second push is uncommitted** (including a newer `neolabs-go` than v0.2.0, so tag v0.3.0 and update `go/neoagent/go.mod` before the next push).

**Shared module (`neolabs-go`)**: all tested with `go vet` and `go test -race`; "vectors" are cases generated from the Node implementation.
- Foundation: `secretbox`, `sessionx`, `passhash`, `secheaders`, `httpx`, `ratelimit`, `ssrf`, `runtimecfg`, `dbx`, `testkit`, `apperr`.
- Login: `pwpolicy`, `totp`, `lockout`, `publicerr`, `webauthnx` (passkeys).
- Email: `servicemail`: config, SMTP sender, single-use tokens, reset-attempt limiter, and the HTML email, which renders **byte for byte** like Node.
- `qrlogin` (screen signed in by a phone: state machine, long polling, device descriptions verified against 56 Node cases), `pairing` (phone signed in by a screen's code).
- `oauthlogin`: OAuth 2 + PKCE sign-in engine (login, register, link, unlink, held usernames, sealed state) with a Google provider; the Google authorization URL matches Node's.

**NeoAgent**
- `schema`, `accounts`, `authapi`: everything from the previous step, plus:
  - Email: sign-up confirmation (an account whose mail cannot be sent is removed and its key returned), forgot/reset password (constant answer and minimum latency, per-link attempt limit, all sessions end), email change with confirmation, notices for password change, email change and unusual sign-ins. The confirmation and reset pages match Node's HTML byte for byte.
  - QR login (challenge, status with long poll, cancel, claim, plus the phone's resolve/decline/approve; wearables get a 90-day session) and pairing.
  - OAuth provider routes (list, begin, register, complete, unlink) and the provider callback with the confirm-in-this-browser step, for account sign-in states.
- `settings` (built by a helper agent): 8 of 13 endpoints (settings read/write, token-usage summary, bring-your-own-key), validated by replaying 125 requests recorded from the real Node route. Three small packages came with it: `agentscope`, `cloudsec`, `timezone`.
- `admin` (built by a helper agent): 19 of 39 endpoints (users, per-user limits, sessions, server config, sign-up policy and keys, access audit, SQL console, env admin grants), checked against ~330 Node vectors. The SQL console also runs on the read-only connection pool.
- Sign-up policy is now read live, so closing registration in the admin page takes effect without a restart.
- Booted against a copy of the real database: auth, providers, admin and settings answer correctly and the original database is untouched.

**Still not ported**
- Auth: OpenRouter sign-in (stores a key in AI settings), account export/delete, GeoIP locations for public addresses.
- Settings (need the AI catalog): model lists, AI-provider list, BYOK list and test. Admin: user erasure, version/update, health, logs, analytics, providers, models, VM config, voice/integration config, messaging.
- The OAuth callback only handles account sign-in states; model-provider and integration states belong to unported domains.
- Unknown `/api/admin/*` paths answer 404 before the auth check (Node answers 401/403).
- Everything else: socket.io, data domains, AI core, integrations and messaging (WhatsApp on whatsmeow, no call rejection), voice, runtime/VMs, CLI and release.

**Next**
1. socket.io layer and its websocket contract tests, then the data domains and the AI core.
2. Tag `neolabs-go` v0.3.0, update `go.mod`, commit and push when you say so.

---

## 11. Out of scope

- Any UI, wording, layout or flow change.
- New features or behaviour changes beyond the three removals in §1. Bugs found while porting are logged and fixed separately so parity checks stay meaningful.
- Rewriting the Flutter client, landing, docs tooling, firmware or the NeoCloud Go client (it only gains shared code).

---

Sources: [whatsmeow](https://github.com/tulir/whatsmeow), [digitorus/pdfsign](https://github.com/digitorus/pdfsign), [pdfcpu signatures](https://pdfcpu.io/core/sign), [zishang520/socket.io](https://pkg.go.dev/github.com/zishang520/socket.io).
