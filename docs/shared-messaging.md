---
title: Shared messaging accounts
sidebar_label: Shared messaging accounts
description: Give everyone on a NeoAgent server one Telegram bot or WhatsApp number to reach their own agent, and what keeps them apart.
---

# Shared messaging accounts

**An admin connects one Telegram bot or WhatsApp number; each person links their own identity to it and reaches only their own agent.**

Nothing here is needed on a single-person install. Until an admin sets up a shared account, nobody sees any of this and **Settings › Platforms** works as it always has. Existing connections are not touched.

## 🧭 Which platforms

| Platform | Shared | Personal | Why |
| --- | --- | --- | --- |
| Telegram | ✅ | ✅ | One bot serves any number of people, and a deep link verifies them in one tap |
| WhatsApp | ✅ | ✅ | A dedicated number people simply message. Use a number you do not mind automating; WhatsApp can ban automated numbers |
| Discord | — | ✅ | A bot can only DM people it shares a server with, so everyone would have to join one server and could see each other. User-installed apps only get slash commands, not a chat |
| Slack | — | ✅ | A Slack app belongs to a workspace, so one global bot cannot span unrelated workspaces |
| Everything else | — | ✅ | Connected per agent, as before |

## 🛠️ Set one up

**In the app:** **Admin › Messaging**. Each platform walks you through it: paste a bot token from [@BotFather](https://t.me/BotFather), or scan the QR code with the shared number. Reconnecting, replacing the token, turning off and removing are in the ⋮ menu.

**Headless:**

```bash
neoagent messaging setup telegram
```

```bash
neoagent messaging setup whatsapp
```

The bot token is prompted for, or piped with `--token-stdin` where there is no terminal. It is never a command-line argument, so it stays out of shell history. The WhatsApp QR prints in the terminal.

| Command | Does |
| --- | --- |
| `neoagent messaging list` | Status, account and how many people are linked (`--json` works) |
| `neoagent messaging setup <platform>` | Connects, or reconnects, and waits until it is live. `--no-personal` turns personal accounts off |
| `neoagent messaging disconnect <platform>` | Stops the account and keeps the links |
| `neoagent messaging remove <platform>` | Deletes the account and every link, after asking (`--yes` to skip) |

The CLI writes to the database and a running server picks the change up within a few seconds, so no restart is needed.

### Settings

| Setting | Effect |
| --- | --- |
| **Offer to users** | Off hides the option and stops the account answering anyone, without deleting links |
| **Allow personal accounts** | Off stops people connecting their own account on that platform. Admins are exempt, connections that already exist keep working |

## 🔗 Link an account

1. Under **Settings › Platforms**, press **Connect** on the platform and pick **Use the shared account** (if the server does not allow personal accounts, this step is skipped).
2. Press the button to open the chat, or scan the QR code to open it on your phone. Telegram sends the code on its own; on WhatsApp press send. You can also send the code by hand.
3. The bot reacts with 👍 and the app shows who you linked as.

- **One agent at a time.** A link routes to the agent you were on when you started it. Link again from another agent to move it.
- **Switching.** Linking retires your personal connection on that agent, and connecting your own account removes the link. You always choose; NeoAgent never falls back from one to the other, because that would change who the messages appear to come from.
- **Unlinking.** **Disconnect** on the card applies at once.
- **Changed number or Telegram account.** Link again from the new one; the old identity stops working immediately.
- **Taken identity.** An identity linked to one NeoAgent account cannot be claimed by another until the first person unlinks it.

## 🛡️ What keeps people apart

| Risk | What stops it |
| --- | --- |
| A stranger uses someone's agent | The sender is resolved from the platform's own sender ID before anything else happens. An unlinked sender creates no message, run, download or reply |
| Someone claims another person's identity | The identity comes from the platform, never from what was typed |
| Someone guesses a code | Codes are 50 bits of randomness, single use, valid for 10 minutes and stored only as a hash. Each sender gets 5 tries per 10 minutes |
| An agent is used to spam | Replies through a shared account can only go to that person's own direct chat, at up to 60 messages a minute. Any other recipient is refused, also for tools and tasks. A personal account is not limited this way, because it sends as you |
| Someone floods the bot | Linked senders are limited to 30 messages a minute. Normal per-account limits still apply to runs |
| Messages mix in a group | Shared accounts answer direct messages only. Group messages and membership events are dropped |
| A file lands in the wrong account | Attachments are stored for the verified sender, after the check |
| A message queued before an unlink | The link is checked again when it is processed |
| Credentials leak | Tokens and QR codes are encrypted at rest and returned only to admins' setup screens as needed. People see the bot's public name and nothing else |

- **Who is asking.** A verified sender counts as the account owner, the same as an approved DM. Their requests follow [their permissions](security-boundaries.md#run-trust).
- **Audit.** Setup, link, unlink and conflict events appear under **Admin › Users › Access activity**, without identities or message text. The admin page shows how many people are linked, not who.

## ⚠️ Know before you offer this

- **Keep codes private.** Whoever sends a code first becomes that account's linked identity, and can then act as its owner. A code on a shared screen is a credential for its 10 minutes. The app shows who linked, so check it.
- **Do not send your code on request.** If someone gets you to send *their* code, your messages go to *their* agent.
- **Linked people are trusted with their own account, not with each other's.** Sharing a bot does not change [what separates accounts](agents-and-users.md#isolation), and accounts are still not a hostile-tenant boundary. With `TERMINAL_ENV=host`, every account's agent runs as the same OS user.
- **The operator can read everything.** Whoever runs the server, and the platform itself, can see these messages.
- **Unlinked people get silence.** A shared bot does not answer strangers, by design, so tell people to link in the app first.
- **New Telegram tokens.** Replacing the bot keeps links, since Telegram IDs do not change, but people must open the new bot once before it can message them.
- **One number, one risk.** If WhatsApp bans or logs out the shared number, everyone on it stops until an admin reconnects. Nobody is moved to another account in the meantime.

## 🔗 Related

- [Integrations and messaging](integrations.md#messaging-channels): personal channels
- [Security and permissions](security-boundaries.md): run trust and what the agent may do
- [Agents and users](agents-and-users.md): accounts, admins and isolation
