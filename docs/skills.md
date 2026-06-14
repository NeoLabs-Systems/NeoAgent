# Skills and MCP

Skills and MCP servers both extend the agent, but they solve different
problems.

## Skills

A skill is a Markdown instruction set for a repeatable workflow. Skills can
teach an agent how to use existing tools, commands, file formats, or local
conventions. They do not add a new security boundary or bypass tool approvals.

Manage skills in **Skills**. NeoAgent includes a catalog of system, network,
document, data, creative, and development workflows. Installed skills are
editable and removable.

Custom skills live in the NeoAgent agent-data directory and are loaded without
restarting the server. Keep them focused, name the actual tools they require,
and never store secrets in them.

Use a skill when:

- the workflow repeats;
- the agent already has the required underlying tools; and
- written procedure is enough to make the work reliable.

## MCP servers

The [Model Context Protocol](https://modelcontextprotocol.io/) connects NeoAgent
to external tool servers. Configure servers in **MCP**, choose the supported
authentication method, and inspect the connection state before assigning the
tools to an agent.

Use MCP when an external system exposes a maintained MCP server or when a
capability requires a real API implementation rather than instructions.

## Choosing the right extension

Prefer, in order:

1. An official NeoAgent integration for supported account services
2. A maintained MCP server
3. A skill using existing tools
4. Browser or shell automation when no structured interface exists

Structured integrations are easier to restrict, audit, and keep stable than UI
automation.
