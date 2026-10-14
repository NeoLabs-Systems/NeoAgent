---
title: How NeoAgent compares
sidebar_label: Why NeoAgent
description: A dated, source-based comparison with self-hosted and hosted personal agents.
---

# How NeoAgent compares

**A dated comparison of product emphasis, not a ranking.**

:::note Reviewed October 14, 2026
These projects change weekly. Check the linked sources before relying on a detail.
:::

## 🏠 Self-hosted agents

| | NeoAgent | OpenClaw | Hermes Agent |
| --- | --- | --- | --- |
| **Main interface** | Web, desktop and Android app | Chat apps plus companion apps | Terminal UI plus chat apps |
| **Computer use** | Per-user cloud computer you can watch and take over | Headless browser on the host | Terminal backends: local, Docker, SSH or cloud sandboxes |
| **Memory** | Structured facts with history and provenance, editable graph | Memory files and plugins | `MEMORY.md` and `USER.md`, optional memory providers |
| **Learned skills** | Auto-learned skills, Teach Mode | Community skills (ClawHub) | Self-written `SKILL.md` files |
| **Multi-user** | Accounts, admin, per-user cloud computer | Single owner per gateway | Single owner |
| **Android** | Built-in emulator it controls over ADB | Companion app | Termux-oriented |
| **Voice and hardware** | Live voice, in-app calls, ESP32 wearable | Voice wake and talk mode | Voice mode in the CLI, chat apps and Discord calls |
| **License** | AGPL-3.0 | MIT | MIT |

`neoagent migrate` imports skills, memory files and selected keys from OpenClaw and Hermes. See [Migration](migration.md).

## ☁️ Hosted agents

| | Runs on | Your own model | Open source | EU consumers | Price |
| --- | --- | --- | --- | --- | --- |
| **NeoAgent** | Your hardware | ✅ Any, local included | ✅ AGPL-3.0 | ✅ Anywhere you host it | Free, plus model costs |
| **Meta Muse** | Meta's cloud | ❌ Meta's model | ❌ | ❌ US and Canada only | Free tier, $20 or $100/month |
| **OpenAI Dots** | OpenAI's cloud | ❌ OpenAI's model | ❌ | ❌ Pro excluded in EEA, CH, UK | ChatGPT Pro or Business Premium |
| **Gemini Spark** | Google's cloud | ❌ Gemini | ❌ | ❌ Excluded in EEA, CH, UK | Google AI Pro or Ultra |
| **Grok Bot** | xAI's cloud | ❌ xAI's model | ❌ | Not confirmed | SuperGrok or Cursor plans |
| **Poke** | Poke's cloud | ❌ | ❌ | ✅ | Free, $19 or $199/month |

## ✅ Choose NeoAgent when

- **You want to host it.** Your server, your data, your choice of model.
- **You want a real app.** Runs, memory, tasks, devices and admin in one interface.
- **Several people share one install.** Separate accounts, memory and cloud computers.
- **It should reach your own things.** Your desktop, Home Assistant, your network, plus its own Android emulator.
- **You want guardrails in code.** Per-tool approval, read-only integrations, credentials the model never sees.

## 🤔 Consider something else when

- **OpenClaw:** you need its channel, plugin or companion ecosystem.
- **Hermes:** you prefer a terminal-first agent.
- **A hosted agent:** you want zero setup and are fine with its cloud, its model and its region list.

## 📎 Sources

- [OpenClaw repository](https://github.com/openclaw/openclaw) · [Hermes Agent repository](https://github.com/NousResearch/hermes-agent)
- [Muse, Dots and Siri AI in Europe](https://trendingtopics.eu/dots-muse-siri-ai-europe) (Trending Topics)
- [OpenAI Dots vs. Meta Muse](https://www.engadget.com/2281289/openai-dot-vs-meta-muse-ai-agents-comparison/) (Engadget)
- [Gemini Spark availability](https://www.clubic.com/actualite-623695-gemini-spark-google-ouvre-son-agent-ia-personnel-au-reste-du-monde-sauf-chez-nous.html) (Clubic)
- [Introducing Grok Bot](https://x.ai/news/introducing-grok-bot) (xAI)
- [Meta Muse vs. Poke](https://www.usecarly.com/blog/meta-muse-vs-poke/) (Carly)
