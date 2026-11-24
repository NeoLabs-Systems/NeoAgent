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

## Account sign-in

Google and OpenRouter can register, sign in, or link to an existing account through the same provider flow. One-time sign-up keys still apply when registration is restricted.

OpenRouter needs an HTTPS or localhost server URL, with no OAuth client ID or secret. It identifies the account by OpenRouter's user ID; it does not provide an email, so new accounts start without one. On first registration, NeoAgent asks you to choose an available username before creating the account. Providers with no usable username or profile name use this same step; returning users skip it. You can set a password in account settings, then add an email. Each successful OpenRouter registration, sign-in, or account link saves the returned model API key encrypted for your default agent, replacing its previous OpenRouter key. Other agents keep their own keys.

Connecting OpenRouter under **Settings › Models › Bring your own key** only connects models; it does not link an account sign-in method. To sign in to an existing NeoAgent account with OpenRouter, link it in account settings first.

Admins can turn OpenRouter account sign-in off under **Admin › Integrations › OpenRouter account sign-in**, alongside the Google configuration. The switch defaults to on and is saved as `NEOAGENT_OPENROUTER_SIGN_IN_ENABLED`. Saving applies immediately to registration, login, account linking, and pending callbacks. Existing sessions and model API keys keep working.

## 🤖 Agents

Create an agent under **Settings › Agents › Add Agent** with a name and what it is responsible for. Instructions, its identifier, status, how it works with other agents and what it may do are under **Advanced settings**.

- **Main agent.** Created automatically for every account. It cannot be archived.
- **Default agent.** The one that answers when you do not pick another; set it under **Settings › Agents**.
- **Separate state.** Each agent has its own conversations, memory, runs, tasks, integration accounts, messaging channels and MCP servers.
- **Profile.** Name, responsibility, description, instructions, and a status of active or paused.
- **Per-agent settings.** **Models**, **Behavior**, **Voice** and **Messaging** apply to the selected agent.
- **Shared settings.** **Permissions** and **Computer & web** apply to all of your agents.

Use separate agents to keep contexts apart, for example a personal agent and a work agent.

### Working together

Agents pass work to each other in the background. You keep talking to one agent; it decides when another one is the better fit.

- **Sub-agents** are short-lived helpers for one part of a run. They have no name, chat or memory of their own and end with the run.
- **Agent tasks** go to one of your lasting agents. The asking agent is not blocked: the other agent works in its own run and the answer comes back when it is done, also after a restart.
- **Delegate or hand over.** When an agent *delegates*, it stays responsible and builds on the result. When it *hands over*, the other agent owns the request from then on and its result is passed on to you.
- **Questions.** The working agent can ask the one that asked; the task waits for the answer.
- **Own chat.** The result also lands in the working agent's chat, so you can carry on with it there.
- **Overview.** **Settings › Agents › Work between agents** lists open and finished work, who asked whom, and the result. **Stop** cancels open work.
- **Who may pass work.** **Can pass work to other agents** is on for the main agent by default; **Other agents can give it work** is on for every other agent. **Only to the agents I pick** limits the targets.
- **Limits.** One run starts at most 3 agent tasks, work goes at most three agents deep and never back to an agent already on it, and at most 2 agent tasks run at once per account.
- **No full history.** The other agent gets the task, the context the asking agent chose, and the expected result, never the whole conversation or memory. What one agent reports is not taken as verified fact by another.

### Agents that set up agents

An agent can set up a new lasting specialist when a job needs its own memory and ownership, or when you ask for one. One-off work and plain schedules do not get their own agent.

- **Your choice.** **Settings › Agents › New agents**: *Never*, *Ask me* (default) or *Allow*. It is the **Set up new agents** category under **Settings › Permissions**.
- **Visible.** The new agent appears in your list with **Set up by …** and the reason; change, pause or archive it like any other.
- **Never more rights.** It gets at most the permissions of the agent that created it, and an agent working on a task for another agent cannot create agents. One run creates at most one agent; an account has at most 12.

### What an agent may do

Under **Advanced settings › What this agent may do**, set any tool category to **Ask first** or **Not allowed** for that agent. This only ever tightens your account's [permissions](security-boundaries.md), also under *Allow all*. Work an agent hands on keeps its limits.

## 👤 User accounts

- **One account per person.** Each account has its own agents, data and cloud computer.
- **Sign-up keys.** Turn on **Admin › Configuration › Access › Require a sign-up key** (or set `NEOAGENT_ALLOW_SIGNUP=false`) and new accounts need a one-time key. Admins create keys one at a time or in batches under **Sign-up keys**, then copy or export them as `.txt`.
- **Not a hostile-tenant boundary.** Read the [isolation notes](#isolation) before giving accounts to people you do not trust.

## 🛡️ Admins

- **First account is admin.** The first account that can sign in becomes admin. An email sign-up counts once confirmed.
- **More admins.** `neoagent admin grant <username>`, or list usernames in `NEOAGENT_ADMIN_USERS`.
- **Revoke.** `neoagent admin revoke <username>` takes effect on the next request.
- **Env list is additive.** Removing a name from `NEOAGENT_ADMIN_USERS` does not revoke it; a CLI revoke stays in force.
- **Reserved names.** A listed username with no account cannot be registered by anyone.
- **Admin tab.** Users, Server, Providers, Models, Integrations, Messaging, Configuration, Analytics and SQL, with a search box.
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
- **Shared messaging.** People on one [shared account](shared-messaging.md) are separated by verified sender, and cannot message anyone but themselves through it.

:::caution Not a hostile-tenant boundary
Accounts are separated at the application level only; read [Security and permissions](security-boundaries.md) before hosting people you do not trust.
:::

## 🔗 Related

- [Shared messaging accounts](shared-messaging.md): one bot or number for everyone on a server
- [Automation and triggers](automation.md): tasks belong to an agent
- [Memory](memory.md): recall is scoped per user and agent
- [Architecture](architecture.md): how agent scope is enforced
