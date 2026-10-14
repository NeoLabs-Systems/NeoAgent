---
format: 1920x1080
duration: 28s
message: "The personal AI agent you host yourself."
arc: Already at work → it remembers and schedules → every step on the record → the line → the mark
audience: Developers deciding whether to self-host NeoAgent
mode: autonomous
music: "Titanium Intent" (supplied), excerpt from 32.79s, ducked bed — see SCRIPT.md
narration: minimal (SCRIPT.md, ElevenLabs eleven_v4)
---

## Video direction

**One idea:** you host it, and it is already at work. The product is the picture for 21 seconds; the brand speaks once, late, then signs.

**Palette (frame.md roles):** canvas `#0E1511` ground with the static `light` radials and `grain` overlay on every frame. Gold `#E1B052` is the only accent (caret, the italic words, the dot). Sage appears only where the real UI already shows it. All product pixels come from `assets/*.png` real captures — never redraw product UI. The one rebuilt component allowed is the typed text inside the real composer (Frame 1).

**Camera convention (shared by every UI frame — the seams depend on it):**
- Framing rule: UI shots centre the main content column (plate-css x 938) at S ≥ 1.45 so the sidebar sits fully off-canvas and no window edge shows; only the Memory pull-back shows the whole window.
- A UI plate is a 3200×2000 capture placed in an `app-window` element sized **1600×1000 CSS px** (so plate pixel ÷ 2 = window CSS px; call this *plate-css*). All coordinates below are plate-css.
- The camera is one wrapper transform: `scale S`, translated so the plate-css point `(cx, cy)` sits at the canvas centre `(960, 540)`. Written as **cam(cx, cy, S)**. At S = 1 the window is 1600×1000; never exceed S = 2.
- Pieces from `assets/layout.json` (values in 2× pixels) sit inside the window at `x/2, y/2` with size `w/2 × h/2`. Placed together over their plate they rebuild the real screenshot exactly.
- Window chrome: `radius-window` corners, 1px hairline ring, deep soft shadow, faint top sheen (frame.md `app-window`).

**Motion grammar:** long-tail decel (`power3.out`, `expo.out` on fast arrivals); camera moves are `power3.inOut`/`expo.inOut`; no overshoot, no bounce, no breathing, no repeat/yoyo. UI pieces enter the way the app would draw them: a short rise of 10–16 plate-css + opacity, or a top-down clip reveal for growing cards; text paragraphs reveal with a left→right line mask. Reveals are paced across each frame — never the whole canvas at t=0.

**Rhythm:** F1 builds (busy), F2 builds then cuts to Tasks (busy), F3 is one long decelerating pull-back (flowing), F4 short and crisp, **F5 is the held breather** (type only, still after it lands), F6 resolves on the mark and holds.

**Negative list:** no purple/blue AI gradients, sparkles, bokeh, glassmorphism, robots; no paragraphs of marketing text; no labels/captions over the UI; no fake cursor in F2–F4; no slideshow (front-load then freeze); no screensaver (many things drifting independently); no slow back-half pans.

## Frame 1 — Already at work

- scene: tight on the real composer, a request types itself and sends; the camera pulls back as the real answer — a table of three flats — draws in row by row
- voiceover: "This is NeoAgent. Ask it something real, and it does the work, right in front of you."
- duration: 7s
- poster: 5.8s
- transition_in: cut
- status: animated
- src: compositions/frames/01-already-at-work.html
- type: hook
- persuasion: Show-don't-tell proof
- beat: curiosity + clarity
- blueprint: prompt-type-submit-generate (Adapt)
- focal: assets/flats-card.png
- roles: chat-empty = plate (the app) · flats-user / flats-avatar / flats-shell / flats-* bands = UI pieces on the plate · layout.json = geometry
- asset_candidates: assets/chat-empty.png — real chat screen, messages erased; assets/flats-user.png — user bubble; assets/flats-avatar.png — agent avatar tile; assets/flats-shell.png — empty answer card; assets/flats-intro.png — answer intro line; assets/flats-thead.png — table header; assets/flats-row1.png — table row 1; assets/flats-row2.png — table row 2; assets/flats-row3.png — table row 3; assets/flats-para.png — explanation paragraph; assets/flats-ask.png — closing question; assets/flats-meta.png — steps toggle + time; assets/layout.json — piece geometry

narrativeRole: open on the product mid-use, no title, no logo.
keyMessage: you ask in plain words, it answers with the actual thing.

Adapt: keep the signature "type into the real input → submit → the machine answers" loop; no status theater, the answer itself is the show.

Geometry (plate-css, from layout.json ÷ 2): composer input box 508–1376 × 890–947; placeholder text "Ask a question or start a task…" at x 565, baseline ≈ 927, Geist 15px, colour ≈ #7E8877; input fill `#171F1A`; send button (gold) 1319–1359 × 899–939. flats-user 696,88 (672×106). flats-avatar 508,212. flats-shell 554,212 (672×435). Bands, all at x 556: intro y 226, thead 259, row1 297, row2 353, row3 409, para 470, ask 548, meta 580.

Scene 1 (0.0–1.7s): cam(942, 918, 1.9) — the composer fills the lower-middle of the canvas, sidebar out of frame. The placeholder is covered by an input-fill patch; the prompt **types on with a gold caret** (`discrete-text-sequence`; the caret is a 2px gold bar that stays solid while typing) in Geist 15px #ECEFE5: "Put the three flats from this morning side by side. I care about rent, size and the bike ride to the studio." — about 70 chars/s with tiny deterministic per-index variation; the single-line field scrolls left so the caret stays visible (like a real input). At 1.55s the send button takes a **press** (scale 1 → 0.9 → 1 over 0.22s, smooth, no overshoot).
Scene 2 (1.7–2.7s): typed text clears and the placeholder returns; `flats-user` rises into place; the camera **pulls back and up** (`multi-phase-camera`, one `expo.inOut` move) to cam(938, 380, 1.45).
Scene 3 (2.7–3.4s): `flats-avatar` fades in; `flats-shell` grows open from its top edge (clip reveal top→bottom, ~0.5s).
Scene 4 (3.4–5.7s): the answer draws in order — intro line, table header, row 1, row 2, row 3 (each rises 12 plate-css + fades, 0.22s apart), then the paragraph and the question reveal with a left→right line mask, then meta. Once the table is in, the full `flats-card` may replace shell+bands invisibly (identical pixels).
Scene 5 (5.7–7.0s): hold, still. Camera fixed at cam(938, 380, 1.45).

- handoff_out: chat window at cam(938, 380, 1.45), all flats pieces fully visible at their layout positions, opacity 1, camera stationary.

## Frame 2 — It keeps working

- scene: the conversation scrolls up as a second request arrives; the real tool steps check off (memory_save, create_task), then the camera dives into the new task and cuts to the Tasks page where it lands first
- voiceover: "Tell it once, and it keeps going. Schedules, briefings, follow-ups — long after you close the tab."
- duration: 6s
- poster: 2.6s
- transition_in: cut
- status: animated
- src: compositions/frames/02-it-keeps-working.html
- type: feature_showcase
- persuasion: Show-don't-tell proof
- beat: ease + control
- blueprint: agent-progress-theater (Adapt)
- focal: assets/cl-createtask.png
- roles: chat-empty = plate · flats-card / cl-* = UI pieces · tasks-empty + task1..4 = second plate · layout.json = geometry
- asset_candidates: assets/chat-empty.png — real chat screen, messages erased; assets/flats-user.png — first user bubble; assets/flats-avatar.png — avatar; assets/flats-card.png — full first answer; assets/cl-user.png — second user bubble; assets/cl-avatar.png — avatar; assets/cl-shell.png — empty answer card; assets/cl-line1.png — "Done. Friday changelog draft runs every Friday at 17:00…"; assets/cl-line2.png — "I kept your rule in mind…"; assets/cl-hide.png — Hide steps; assets/cl-runhead.png — run header with Completed pill; assets/cl-steps.png — 2 steps chip; assets/cl-memsave.png — memory_save row; assets/cl-createtask.png — create_task row; assets/cl-meta.png — timestamp; assets/cl-card.png — full second answer; assets/tasks-empty.png — Tasks page, cards erased; assets/task1.png — Friday changelog draft card; assets/task2.png — Morning briefing card; assets/task3.png — Half marathon check-in card; assets/task4.png — Flat listings watch card; assets/layout.json — piece geometry

narrativeRole: the agent does work that outlives the chat.
keyMessage: one sentence becomes a task that keeps running.

Adapt: keep the receipt rows arriving and checking off; the trigger is the sent message, not a menu click; end with a push into the confirmation that cuts to where the task now lives.

Geometry: the cl-* pieces come from a capture scrolled 343 plate-css further than Frame 1. In this frame, place cl-* at their layout.json positions, and place the Frame-1 pieces (flats-user, flats-avatar, flats-card) at their positions **minus 343 plate-css in y** — that is the scrolled state. cl-user 696,322 · cl-avatar 508,446 · cl-shell 554,446 (672×396) · bands at x 556: line1 y 462, line2 494, hide 526, runhead 559, steps 618, memsave 664, createtask 738, meta 800. Tasks plate pieces: task1 315,229 · task2 315,462 · task3 315,704 · task4 315,946 (each 1246 wide).

Scene 1 (0.0–1.1s): handoff_in from Frame 1. The whole message column (flats pieces) **scrolls up 343 plate-css** on one `power3.inOut` move while `cl-user` rises in at the bottom (cut-the-curve continuity: same upward direction); the camera eases to cam(938, 560, 1.45).
Scene 2 (1.1–3.0s): `cl-avatar` + `cl-shell` open top→bottom; the answer draws in reading order, the way the app paints it: line1 and line2 (left→right line mask), hide, then the receipt — run header (its Completed pill fades a beat later), "2 steps" chip, **memory_save** and **create_task** rising in on their own beats (0.3s apart), then meta. Everything has landed before the zoom.
Scene 3 (3.0–3.9s): **zoom-to-target** (`coordinate-target-zoom`) on the create_task row (centre ≈ 890, 764) to S≈2.0, accelerating; at peak velocity a **zoom-through seam** (`cut-catalog.md`) swaps the window plate to `tasks-empty` at cam(938, 410, 1.42) and keeps pushing forward (same direction as before the seam).
Scene 4 (3.9–6.0s): the camera settles at cam(938, 400, 1.5); `task1` (Friday changelog draft — the one just created) lands first with a short rise; task2, task3, task4 **cascade** in below (`grid-card-assemble`, 0.14s apart). Hold still from 5.2s.

- handoff_in: chat window at cam(938, 380, 1.45), flats pieces at Frame-1 positions, opacity 1, stationary.

## Frame 3 — It remembers

- scene: one point of light — Maya — and a single long pull-back reveals the knowledge graph growing outward from it, then the whole Memory page
- voiceover: "It remembers the people, places and plans that matter to you."
- duration: 5s
- poster: 4.2s
- transition_in: blur-crossfade
- status: animated
- src: compositions/frames/03-it-remembers.html
- type: benefit_highlight
- persuasion: Future pacing
- beat: awe + trust
- blueprint: zoom-out-workspace-reveal (Reproduce)
- focal: assets/memory.png
- roles: memory = plate (full real page) · layout.json = geometry (maya_node, graph_box)
- asset_candidates: assets/memory.png — Memory page with stats and knowledge graph; assets/layout.json — node and graph geometry

narrativeRole: show what it accumulates about you, owned by you.
keyMessage: it remembers what you told it once.

Geometry: Maya node centre ≈ (980, 737) plate-css; graph box 335–1541 × 393–1000.

Scene 1 (0.0–1.0s): open TIGHT at cam(980, 737, 2.0) on the Maya node; a soft **radial mask** centred on the node is small (radius ≈ 60 plate-css) so only Maya and the first edges show on the canvas ground; gold `ambient-glow-bloom` behind the node.
Scene 2 (1.0–3.9s): ONE continuous decelerating **zoom-out** (`multi-phase-camera`, `power3.out`) to cam(800, 520, 1.02) while the radial mask radius grows (`expo.out`) until the full plate is unmasked — nodes appear ring by ring as the reveal passes them; the glow fades as the page arrives.
Scene 3 (3.9–5.0s): hold on the whole Memory page, still.

## Frame 4 — Every step on the record

- scene: the Runs page; the selected run lights, its stats fill cell by cell and the timeline bars draw in the order the tools ran
- voiceover: "Every run, every tool, every step — right there on the record."
- duration: 4.5s
- poster: 3.6s
- transition_in: push-slide LEFT
- status: animated
- src: compositions/frames/04-on-the-record.html
- type: feature_showcase
- persuasion: Risk reversal
- beat: control + confidence
- blueprint: compose
- focal: assets/runs.png
- roles: runs = plate · layout.json = geometry (list_panel, detail_panel, stats_row, timeline, selected_row)
- asset_candidates: assets/runs.png — Runs page: run list + run detail with stats and timeline; assets/layout.json — region geometry

narrativeRole: transparency — nothing it does is hidden.
keyMessage: every run keeps its steps, tools, tokens and model.

Geometry: selected row 318–716 × 325–388; detail panel 733–1559 × 125–960; stats row 756–1536 × 248–310 (6 cells, ~131 wide each); timeline 756–1536 × 380–480 (bars at ≈ y 425 and 466, x ≈ 1130 and 1230).

Scene 1 (0.0–1.1s): cam(938, 380, 1.45). The plate is visible except the detail panel content, which is held behind masks; the selected-row highlight sweeps in left→right (clip reveal) — the run is chosen.
Scene 2 (1.1–3.2s): detail reveals top-down: title area, then the six stat cells **cascade** left→right (each a clip reveal, 0.09s apart), then the timeline rows appear and each green bar **draws** left→right in run order (memory_recall, then generate_table) — `stat-bars-and-fills`.
Scene 3 (3.2–4.5s): hold, still.

## Frame 5 — The line

- scene: the ground clears; one sentence sets in Fraunces — "The personal AI agent you host yourself." — with "host yourself." in gold italic
- voiceover: "The personal AI agent you host yourself."
- duration: 4s
- poster: 3.2s
- transition_in: blur-crossfade
- status: animated
- src: compositions/frames/05-the-line.html
- type: benefit_highlight
- persuasion: Value framing
- beat: clarity + ownership
- blueprint: kinetic-type-beats (Adapt)
- asset_candidates:

narrativeRole: say the one thing, once.
keyMessage: the personal AI agent you host yourself.

Adapt: no token swap; the statement builds word by word onto a held lockup — the shot's stillness after it lands is the payload.

Scene 1 (0.0–0.5s): ground only (canvas + light + grain).
Scene 2 (0.5–2.2s): `display` Fraunces 112px, two lines, left-aligned at x 160, vertically centred: "The personal AI agent" / "you *host yourself.*" — **per-word staggered reveal** (`dynamic-content-sequencing`): each word rises 24px from a line mask, 0.11s apart, `power3.out`; "host yourself." is `display-italic` gold and lands last, slightly slower.
Scene 3 (2.2–2.9s): beneath, the gold dot lands and the `label` eyebrow types in right after it: "● SELF-HOSTED · OPEN SOURCE" (label + label-quiet).
Scene 4 (2.9–4.0s): hold, still.

## Frame 6 — NeoAgent

- scene: the dot-matrix mascot assembles dot by dot, blinks once, and the wordmark with the repository address settles beside it
- voiceover: "NeoAgent. Open source, and all yours."
- duration: 3.5s
- poster: 2.9s
- transition_in: crossfade
- status: animated
- src: compositions/frames/06-neoagent.html
- type: branding
- persuasion: Brand recall
- beat: confidence
- blueprint: logo-assemble-lockup (Reproduce)
- asset_candidates:

narrativeRole: sign the film.
keyMessage: NeoAgent — github.com/NeoLabs-Systems/NeoAgent.

Scene 1 (0.0–1.1s): centred lockup position: `mascot-tile` 220px at left of a centred group. The tile scales from 0.92 → 1 with a fade; its lit dots switch on **row by row from the top** (deterministic order, 0.03s per dot), each with a tiny glow pop (no overshoot).
Scene 2 (1.1–2.0s): `wordmark` "NeoAgent" (Geist 600, 96px, ink) slides in from 30px left behind a mask; below it `label-quiet` "github.com/NeoLabs-Systems/NeoAgent" fades up.
Scene 3 (2.0–3.5s): the mascot **blinks** once at 2.4s (frame.md blink). Hold; final 0.35s the whole frame fades to the canvas colour (the film's only exit).
