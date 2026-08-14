# Architecture

NeoAgent is a Node.js service with Flutter clients. The server owns
authentication, model access, agent execution, tools, integrations, automation,
memory, persistence, and real-time state.

## Main components

```text
Flutter clients and messaging channels
                |
        Express + Socket.IO
                |
  agents / AI engine / tasks / integrations
                |
 runtime backends / SQLite / agent data
```

### Server

`server/index.js` creates the application and service managers. Express routes
handle HTTP boundaries and delegate behavior to services. Socket.IO publishes
run progress, approvals, messages, device state, and operational updates.

The server uses CommonJS. Routes should remain thin; business logic belongs in
`server/services/`.

### Clients

The Flutter codebase produces the web operator interface, Android client,
desktop clients, and Android launcher build. `MainController` is the root
application state object. Platform behavior is implemented through conditional
bridge files and native Android code where required.

### Persistence

NeoAgent uses one `better-sqlite3` database instance. It stores users, agents,
settings, conversations, runs, tasks, integration connections, memory,
health data, permissions, and operational state.

Runtime files live outside the package source under `NEOAGENT_HOME`. Schema
changes are applied through the migration layer rather than ad hoc service SQL.

### Execution runtimes

Browser, desktop, terminal, and file tools use one selected Computer provider
per user. The cloud provider is a persistent QEMU Linux guest; desktop builds
can instead supply the local macOS, Windows, or Linux session through the same
runtime contract and permission gate. Android remains a separate host ADB
capability.

## Subsystem guides

- [Agent run lifecycle](agent-run-lifecycle.md)
- [Memory architecture](memory-architecture.md)
- [Runtime and tool execution](runtime-and-tools.md)
- [Agents, automation, and triggers](automation-architecture.md)
- [Integrations and messaging](integrations-architecture.md)
- [Clients and device bridges](clients-and-devices.md)
- [Persistence and migrations](persistence.md)
- [Development and testing](development.md)
