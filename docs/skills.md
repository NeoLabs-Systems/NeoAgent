---
title: Skills and MCP
sidebar_label: Skills and MCP
description: Teach the agent repeatable workflows with Markdown skills, and add external tools through MCP servers.
---

# Skills and MCP

**Skills teach the agent a workflow in Markdown; MCP servers add tools from outside NeoAgent.**

Manage both under **Tools**, which has the tabs **All**, **Integrations**, **MCP**, **Skills** and **skills.sh**.

## 📄 Skills

- **Format.** A `SKILL.md` file: frontmatter with a required `name`, then Markdown instructions.
- **No new powers.** A skill guides tools the agent already has; approvals still apply.
- **Per user.** Stored in `~/.neoagent/agent-data/skills/users/<userId>/<name>/SKILL.md`.
- **Loaded at once.** Skills added in the app load immediately. Files copied in by hand load at the next server start.
- **Controls.** Each skill has **Available to the agent**, **Edit instructions** and **Delete**. **Add › New skill** writes one from scratch.
- **No secrets.** Name the tools a skill needs; never paste credentials into it.

```markdown
---
name: weekly-invoice-check
description: Find unpaid invoices in the shared Drive folder and list them.
---
Search the "Invoices" Drive folder for files from the last 30 days...
```

### Install from skills.sh

1. Open **Tools › skills.sh**, or **Add › Add from skills.sh**.
2. Search the [skills.sh](https://skills.sh) library, or paste a skills.sh URL, an `owner/repo/skill` ID, or an `npx skills add` command.
3. Press **Get**. The skill's files are fetched from GitHub and saved as your skill.

- **Limits.** Up to 200 files, 1 MB per file, 8 MB per skill.
- **Editable.** Installed skills can be changed or removed like your own.

:::note Bundled store removed
NeoAgent no longer ships a built-in skill store, and skills installed from it are removed when skills load.
:::

## 🧠 Auto-learned skills

The agent turns workflows it repeats into skills on its own.

- **On by default.** Per-agent setting `auto_skill_learning`. The app has no switch yet; send `{"auto_skill_learning": false}` to `PUT /api/settings`.
- **When it looks.** After substantial runs (a long request, or at least three completed tool steps), from chat or scheduled tasks.
- **How it decides.** A model review ignores, observes, creates or updates. A workflow must be seen twice before a new skill is written.
- **Where they appear.** **Tools › Skills**, marked as learned.
- **Retirement.** After at least 5 uses with a success rate of 25% or less, a learned skill is disabled, not deleted.
- **Outside the permission gate.** Learning writes skills directly; **Skill Changes** governs only the agent's own skill tools.

## 🎓 Teach Mode

Show the agent a task once on the cloud computer and it writes a skill from the demonstration.

1. Open **Devices**, start the cloud computer and press **Teach**.
2. Answer **What should NeoAgent learn?**
3. Do the task on the desktop, then press **Finish**.

- **Cloud computer only.** Not available on **This device**.
- **Private by default.** Typed text is stored as a placeholder; screenshots are skipped while a password field is visible.
- **Deleted afterwards.** The encrypted recording is wiped on finish, cancel, 30 idle minutes or restart.

Details of what is recorded: [Devices](devices.md#teach-mode).

## 🔌 MCP servers

The [Model Context Protocol](https://modelcontextprotocol.io/) connects NeoAgent to external tool servers.

- **Add one** under **Tools › MCP** with its URL, authentication and **Assigned Agent**.
- **Remote only.** HTTP(S) servers over SSE. Local stdio servers are not supported.
- **Authentication.** No auth, Bearer token, or OAuth with your own client ID. The OAuth callback is `PUBLIC_URL/api/mcp/oauth/callback`.
- **Status.** Each server shows Running, Error or Stopped, its tool count, and **Start**/**Stop**. Failed servers reconnect on their own.
- **Approval.** MCP tools fall under **External & MCP Tools**, which asks first by default.
- **From chat.** The agent can add a server with `mcp_add_server`; a [tainted run](security-boundaries.md#run-trust) asks you first.

## 🧭 Which extension to use

1. **An official integration** for supported account services.
2. **A maintained MCP server** when a system offers one.
3. **A skill** when existing tools can do the work and written steps make it reliable.
4. **Browser or shell automation** only when no structured interface exists.

Structured tools are easier to restrict, audit and keep stable than UI automation.
