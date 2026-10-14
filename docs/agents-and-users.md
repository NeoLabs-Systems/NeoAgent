---
title: Agents and users
sidebar_label: Agents and users
description: How NeoAgent separates sign-in accounts from configured AI identities, and how admins and teams work on one server.
---

# Agents and users

**A user is an account that signs in; an agent is an AI identity that a user owns and configures.**

| Concept | What it is | Managed in |
| --- | --- | --- |
| User | An account on your NeoAgent server | Sign-up, **Admin › Users** |
| Agent | An AI identity owned by one user | **Settings › Agents** |

## 🤖 Agents

- **Main agent.** Created automatically for every account. It cannot be archived.
- **Default agent.** The one that answers when you do not pick another; set it under **Settings › Agents**.
- **Separate state.** Each agent has its own conversations, memory, runs, tasks, integration accounts, messaging channels and MCP servers.
- **Profile.** Name, description, responsibilities, instructions, and a status of active or paused.
- **Per-agent settings.** **Models**, **Behavior**, **Voice** and **Messaging** apply to the selected agent.
- **Shared settings.** **Permissions** and **Computer & web** apply to all of your agents.

Use separate agents to keep contexts apart, for example a personal agent and a work agent.

### Delegation

- **Can delegate tasks to other agents.** On for the main agent by default. Use it for orchestrator agents.
- **Can receive delegated tasks.** On for every other agent by default. Turn it off to keep an agent fully separate.
- **Restrict delegation targets.** Limits which agents a delegating agent may hand work to.
- **Shared trust.** A delegated run keeps the caller's run trust; see [Security and permissions](security-boundaries.md).

## 👤 User accounts

- **One account per person.** Each account has its own agents, data and cloud computer.
- **Sign-up control.** `NEOAGENT_ALLOW_SIGNUP=false`, or the switch in the **Admin** tab, closes registration.
- **Not a hostile-tenant boundary.** Read the [isolation notes](#isolation) before giving accounts to people you do not trust.

## 🛡️ Admins

- **First account is admin.** The first account that can sign in becomes admin. An email sign-up counts once confirmed.
- **More admins.** `neoagent admin grant <username>`, or list usernames in `NEOAGENT_ADMIN_USERS`.
- **Revoke.** `neoagent admin revoke <username>` takes effect on the next request.
- **Env list is additive.** Removing a name from `NEOAGENT_ADMIN_USERS` does not revoke it; a CLI revoke stays in force.
- **Reserved names.** A listed username with no account cannot be registered by anyone.
- **Admin tab.** Users, Server, Providers, Models, Integrations, Configuration, Analytics and SQL, with a search box.
- **No self-delete.** An admin account cannot delete itself; revoke admin first.
- **Older installs.** A single-account install promotes its only account. With several, run `neoagent admin grant <username>`.

Admin changes are made by the operator from the CLI or the env list, never from inside the app.

## 🤝 Teams

- **Team tab.** Shows who manages you, whom you manage, and your invite links.
- **Unmanaged by default.** You decide which tool categories your agents may use under **Settings › Permissions**.
- **Invite links.** List the tool categories the recipient may use, with an expiry (up to 90 days) and single-use or reusable.
- **Only what you hold.** A link cannot hand out a category you lack, and never grants admin.
- **Joining.** The recipient enters the link on the **Team** tab, reviews the manager and permissions, and confirms.
- **What a manager controls.** Tool categories such as shell, file writes and desktop control. A manager's "off" beats the account's own setting, including allow-all.
- **What a manager sees.** Username, display name and those permissions. Never chats, memories, files or email.
- **Chains.** Up to four managers above an account. A decision higher up wins and shows as locked, with who made it.
- **Leaving.** A managed account can leave at any time; the manager can also stop managing it.
- **Deleted managers.** The people they managed move up to the next manager, or become independent.
- **Audit.** Admin grants, invite links and team changes appear under **Admin › Users › Access activity**.

## 🧱 Isolation {#isolation}

- **Data scope.** Application data is scoped per user and, where it applies, per agent.
- **Cloud computer.** One per user; QEMU and Docker backends separate users, `TERMINAL_ENV=host` does not.
- **Integration credentials.** Stored on the server and bound to one user and agent.
- **Android.** ADB commands run on the NeoAgent host against the attached device.

:::caution Not a hostile-tenant boundary
Accounts are separated at the application level only; read [Security and permissions](security-boundaries.md) before hosting people you do not trust.
:::

## 🔗 Related

- [Automation and triggers](automation.md): tasks belong to an agent
- [Memory](memory.md): recall is scoped per user and agent
- [Architecture](architecture.md): how agent scope is enforced
