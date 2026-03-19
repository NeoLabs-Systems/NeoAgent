<div align="center">

# NeoAgent

**Your agent. Your server. Your rules.**

[![Node.js](https://img.shields.io/badge/Node.js-18+-5fa04e?style=flat-square&logo=node.js&logoColor=white)](https://nodejs.org)
[![SQLite](https://img.shields.io/badge/SQLite-WAL-003b57?style=flat-square&logo=sqlite&logoColor=white)](https://sqlite.org)
[![Flutter](https://img.shields.io/badge/Flutter-web%20%2B%20android-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-a855f7?style=flat-square)](LICENSE)

A self-hosted, proactive AI agent with a Flutter client for web and Android.  
Connects to OpenAI, xAI, Google, and local Ollama with `qwen3.5:4b`.  
Runs tasks on a schedule, controls a browser, manages files, and talks to you over Telegram, Discord, or WhatsApp.

```bash
npm install -g neoagent
neoagent install
```

From source:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/NeoLabs-Systems/NeoAgent/main/install.sh)
```

Manage the service:
```bash
neoagent status
neoagent update
neoagent logs
```

Build the Flutter web client:
```bash
npm run flutter:build:web
```

The installer and npm package ship the bundled web client from `server/public`, so Flutter is only needed when you want to rebuild the frontend locally.

Local development helpers live in `dev/`:
```bash
./dev/backend.sh
./dev/web.sh
./dev/stack.sh
./dev/test.sh
```

---

[⚙️ Configuration](docs/configuration.md) · [🧰 Skills](docs/skills.md) · [🐛 Issues](https://github.com/NeoLabs-Systems/NeoAgent/issues)

---

*Made with ❤️ by [Neo](https://github.com/neooriginal) · [NeoLabs Systems](https://github.com/NeoLabs-Systems)*

</div>
