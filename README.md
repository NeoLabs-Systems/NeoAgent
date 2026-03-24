<h1 align="center">NeoAgent</h1>
<img width="1462" height="696" alt="WebUI" src="https://github.com/user-attachments/assets/3c76d59a-b6e3-4698-929b-9c94741ccf1e" />
<img width="1001" height="2048" alt="Mobile Telegram" src="https://github.com/user-attachments/assets/1fd41a9b-5452-4aa4-9478-888c8ad7363a" />

<p align="center"><strong>Your agent. Your server. Your rules.</strong></p>

<p align="center">
  <a href="https://nodejs.org"><img src="https://img.shields.io/badge/Node.js-18+-5fa04e?style=flat-square&logo=node.js&logoColor=white" alt="Node.js"></a>
  <a href="https://sqlite.org"><img src="https://img.shields.io/badge/SQLite-WAL-003b57?style=flat-square&logo=sqlite&logoColor=white" alt="SQLite"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-web%20%2B%20android-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-a855f7?style=flat-square" alt="License"></a>
</p>


<p align="center">
  A self-hosted, proactive AI agent with a Flutter client for web and Android.<br>
  Connects to OpenAI, xAI, Google, MiniMax Code, and local Ollama.<br>
  Runs tasks on a schedule, controls a browser, manages files, and talks to you over Telegram, Discord, or WhatsApp.
</p>

## Install

```bash
npm install -g neoagent
neoagent install
```

## Manage the Service

```bash
neoagent status
neoagent channel beta
neoagent update
neoagent fix
neoagent logs
```

Use `neoagent fix` if a self-edit or broken local install leaves NeoAgent in a bad state. On git installs it backs up runtime data, saves local tracked changes, resets tracked source files, reinstalls dependencies, and restarts the service.

## Links

[⚙️ Configuration](docs/configuration.md) · [🧰 Skills](docs/skills.md) · [🐛 Issues](https://github.com/NeoLabs-Systems/NeoAgent/issues)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/neooriginal">Neo</a> · <a href="https://github.com/NeoLabs-Systems">NeoLabs Systems</a>
</p>
