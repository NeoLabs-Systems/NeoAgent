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

Optional SMTP configuration enables:

- Signup confirmation
- Password reset
- Email-change confirmation
- New-device or unusual-login notifications
- Password and account-change notifications

See [Configuration](configuration.md#service-email) for the server variables.

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
