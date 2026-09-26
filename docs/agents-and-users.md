---
title: Agents and users
sidebar_label: Agents and users
description: How NeoAgent separates sign-in accounts from configured AI identities, and how multi-user deployments stay isolated.
---

# Agents and users

*Two separate concepts: who signs in, and which AI identity does the work.*

NeoAgent separates two concepts:

- A **user** is an account that can sign in to the server.
- An **agent** is a configured AI identity owned by a user.

## 🤖 Agents

The main agent is created automatically. Additional agents are managed in the
operator interface and can be used as specialists.

Each agent has its own conversations, memory, model settings, integrations,
messaging assignments, tasks, and run history. This separation lets one user
maintain, for example, a personal agent and a work agent without merging their
context.

Agents can also be marked for orchestrator use. An orchestrator can delegate
work to other agents; a normal specialist is intended to complete its assigned
run directly.

## 👤 User accounts

Self-hosted installations can support more than one account. Administrative
controls include account management, provider configuration, logs, and runtime
updates.

## Admins

- **First account is admin** — on a fresh install the first account created becomes the admin.
- **More admins** — `neoagent admin grant <username>`, or list usernames in `NEOAGENT_ADMIN_USERS`.
- **Revoke** — `neoagent admin revoke <username>`; it applies on the next request.
- **Admin tab** — admins get an **Admin** tab in the app with a search box: users, server, providers, models, integrations, configuration, billing, analytics, SQL, and the access activity log.
- **No self-delete** — an admin account can't delete itself; revoke admin first.
- **Existing installs** — a single-account install promotes its only account; with several accounts, run `neoagent admin grant <username>` (startup and `neoagent status` remind you).

## Teams

- **Team tab** — every account has a **Team** tab: who manages you, whom you manage, and your invite links.
- **On your own** — by default you decide which tools your agent may use (Tool Permissions).
- **Invite links** — anyone can create a link listing which tools the recipient's agent may use, with an expiry and single-use or reusable. A link can only hand out tools you hold yourself, and never grants admin.
- **Joining** — the recipient enters the link on the **Team** tab, sees who will manage them and what they'll be allowed, and confirms.
- **What a manager controls** — the tool permission categories (shell, file writes, desktop control, …). A manager's "off" beats the account's own Tool Permissions setting, including "Allow all".
- **What a manager sees** — username, display name and those permissions. Never chats, memories, files or email.
- **Chains** — A manages B, B manages C (up to four levels). A decision higher up wins and shows as locked, with the name of whoever made it.
- **Leaving** — a managed account can leave at any time; the manager can also stop managing it.
- **Removing a manager** — when a manager's account is deleted, the people they managed move up to their manager (or become independent at the top).
- **Audit** — admin grants, invite links and team changes are logged under **Admin › Users › Access activity**.

## 🧱 Isolation model

Application data is scoped by user and, where applicable, agent. The default
Linux computer is created per user. Official integration credentials remain
server-side and are assigned to a particular user and agent.

:::caution Not a hostile-tenant boundary
This is application and runtime isolation, not a promise that every capability
runs inside a VM. Android commands run through ADB on the NeoAgent host, while
the persistent Linux computer grants access to its guest data and sessions.
Read [Security boundaries](security-boundaries.md) before hosting untrusted
users.
:::

## 🔗 Related

- [Automation and triggers](automation.md) — tasks are owned by an agent
- [Memory](memory.md) — recall is scoped per user and agent
- [Architecture](architecture.md) — how agent scope is enforced
