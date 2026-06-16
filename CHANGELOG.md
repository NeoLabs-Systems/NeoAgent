# Changelog

## v3.0.0 - 2026-06-16

NeoAgent 3.0 promotes the beta agent-loop work to the stable release channel.
This is a major release because it changes the default behavior of long-running
runs, messaging delivery, progress reporting, tool execution, GitHub issue
implementation, and artifact handling.

The headline change is reliability: a messaging run should no longer send a
single interim note, continue working internally, and then finish silently. The
agent loop now keeps final delivery state separate from progress/interim
activity, continues in the same run instead of replaying whole attempts, and
gives the model better tools and context to produce concrete results.

### Major behavior changes

- Promoted the reworked agent loop from beta to the stable `main` release path.
- Messaging runs now distinguish visible interim activity from terminal final
  delivery. Interim updates do not suppress the final reply fallback.
- Long-running work now stays inside the active loop instead of relying on
  full-run restarts that can repeat checkout, search, and read steps from the
  beginning.
- Progress updates are model-authored and grounded in recent tool activity. The
  runtime no longer sends canned user-facing "still working" text.
- Short tasks are optimized for speed. The system avoids early visible update
  chatter and avoids task-style ceremony when a direct answer is enough.
- The runtime treats read-only inspection differently from implementation
  progress, so repetitive reads/searches are less likely to look like meaningful
  forward motion.
- Command, GitHub, and file-tool results are compacted and summarized more
  carefully to preserve useful context while avoiding prompt bloat.

### Agent loop and messaging reliability

- Reworked finality handling so a run is not considered complete merely because
  the assistant sent an interim progress message.
- Added stricter final-delivery accounting for messaging integrations, including
  separate state for interim sends, explicit final sends, fallback final content,
  and no-response outcomes.
- Fixed the case where an interim message such as "let me check that" could
  prevent the actual final answer from being delivered to the originating chat.
- Improved blank-reply recovery so transient empty model outputs no longer
  immediately collapse a messaging run into silence or a full replay.
- Added model timeout handling around long or stalled provider calls.
- Added same-run recovery paths for messaging errors instead of restarting the
  whole run and losing useful local state.
- Added iteration-limit wrap-up behavior based on the Hermes pattern: when the
  model exhausts a bounded loop, it gets a final tool-less chance to summarize,
  finish, or report a blocker rather than falling through to an opaque error.
- Improved task-completion prompting so the model can finish explicitly instead
  of continuing to inspect indefinitely.
- Added progress-ledger events and state updates for verified progress,
  heartbeat/liveness checks, stalled runs, and resumed runs.
- Tuned progress notification timing so short tasks do not receive premature
  updates, while longer tasks still receive user-visible feedback.
- Grounded progress-composer context in real recent tool summaries instead of
  only bare tool names, reducing invented status messages.
- Removed hardcoded runtime-authored progress prose. If a visible update is
  sent, it comes from the model path and is based on the current run state.
- Prevented mid-run messages from silencing the supervisor in cases where final
  delivery had not yet happened.

### Long-running code tasks

- Added workflow guidance for implementation tasks: fetch the issue once,
  establish a writable local checkout, edit/test locally, and use GitHub API
  file operations as fallback rather than the primary coding path.
- Improved GitHub issue and repository argument handling so tools accept the
  common `owner/repo` shape and separate `owner` plus `repo` fields.
- Improved GitHub API request behavior for plain JSON payloads and non-GET
  methods.
- Improved GitHub file creation/update behavior so plain text can be passed
  directly without forcing the model into unnecessary base64 encoding work.
- Classified failed writes and failed GitHub API attempts more accurately so
  they do not count as useful implementation progress.
- Classified read-only commands separately from state-changing commands,
  including common inspection commands such as `cat`, `grep`, `find`, `sed`,
  `head`, `tail`, `wc`, `curl`, and base64-only extraction.
- Added stronger duplicate-output and fingerprint tracking for repeated tool
  activity.
- Added anti-analysis-paralysis steering that names already-read targets and
  encourages acting on existing evidence instead of re-reading the same files
  through slightly different commands.
- Tuned context compaction to keep important file contents available longer
  during multi-step implementation work.

### Tools and runtime ergonomics

- Added multi-file reading support through `read_files`.
- Added targeted range replacement support through `replace_file_range`.
- Improved workspace file-tool preference so the model can operate on the
  mounted checkout directly instead of scraping files through shell output.
- Added aliases for common file-tool argument names, reducing failures caused by
  small schema mismatches.
- Improved write/edit/range handling so tool calls can be more direct and less
  dependent on shell workarounds.
- Improved tool argument aliasing generally, especially for GitHub and file
  operations.
- Improved runtime workspace mounting so file tools can see the same checkout
  that shell commands use.
- Reduced command echo leakage into messaging updates.
- Improved read-only progress classification for `execute_command` and
  GitHub/API inspection calls.

### Artifacts, deliverables, and context size

- Fixed invalid local artifact candidates so missing files are dropped instead
  of being carried forward as fake artifacts.
- Hardened artifact extraction from command, GitHub, tree, content, and other
  evidence-style outputs so generic `path` fields do not become artifact spam.
- Restricted implicit artifact scanning to explicit deliverable/artifact
  containers and known artifact URLs.
- Fixed artifact extraction from tool URLs.
- Fixed deliverable selector crash recovery.
- Reduced prompt bloat from repeated stat warnings and invalid artifact records.
- Preserved artifact-stat warnings as non-fatal diagnostics rather than treating
  them as run-ending errors.

### Messaging and automation UX

- Kept interim updates non-terminal unless the update explicitly expects a user
  reply.
- Ensured final fallback delivery sends exactly once when final assistant text
  exists and no explicit final platform delivery has already happened.
- Preserved duplicate-send suppression for explicit final `send_message` calls.
- Added recovery for blocked runs so the user receives a blocker reply instead
  of only seeing an earlier progress note.
- Avoided visible progress pings for short tasks by delaying progress updates
  until the task has actually taken long enough to justify them.
- Made progress updates describe actual recent activity instead of generic
  runtime status.
- Added Android notification trigger support for starting runs from device
  notifications.

### UI, mobile, and docs

- Stabilized Flutter chat scrolling behavior.
- Improved README readability and project positioning.
- Updated the package description to reflect the current product scope:
  long-running tasks, automation, messaging, device control, and local memory.

### Reliability and security

- Added immediate error guidance for tool failures so the loop can recover
  without repeatedly making the same failing call.
- Added research-budget and output-fingerprint guardrails for read-heavy work.
- Improved MCP/tool failure recovery for blank or malformed tool results.
- Improved policy and tool-dispatch behavior around argument validation and
  execution state.
- Kept the release path on the existing stable workflow: promote `beta` into
  `main`, build the bundled web client in CI, publish the npm package, create
  the GitHub release, and attach release assets.

### Upgrade notes

- This release intentionally changes long-running run behavior. Operators should
  restart the server after upgrading so active loop, delivery, and progress
  supervisor code all run from the same version.
- If you have custom prompts that expected runtime-authored status messages,
  update them to rely on model-authored `send_interim_update` behavior instead.
- If you monitor run metadata directly, expect additional progress-ledger fields
  and event types related to verified progress, heartbeats, stalled state, and
  resumed state.
- Existing external HTTP and websocket schemas remain compatible for this
  release.
