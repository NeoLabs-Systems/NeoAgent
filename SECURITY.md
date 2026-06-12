# Security Policy

## Supported Versions

Security fixes are applied to the latest stable release and, when affected, the
current beta line. Older releases should be updated before a report is
validated.

## Report a Vulnerability Privately

Do not open a public issue for a suspected vulnerability.

Use GitHub's
[private vulnerability reporting](https://github.com/NeoLabs-Systems/NeoAgent/security/advisories/new)
to send the report to the maintainer. If that form is unavailable, email
`support@neoagent.ai`.

Include:

- The affected version or commit.
- The affected component and runtime profile.
- Reproduction steps or a minimal proof of concept.
- The impact you observed.
- Any known mitigations.

Do not include live credentials, personal data, or access to a production
system. Use test accounts and redact logs.

The maintainer will confirm receipt, investigate the report, coordinate a fix,
and credit the reporter when requested and appropriate. Please allow time for a
release before publishing technical details.

## Security Scope

Reports are especially useful when they involve:

- Authentication or authorization bypass.
- Cross-user or cross-agent data access.
- Secret, token, or personal-data exposure.
- Command execution outside the configured runtime boundary.
- Browser, Android, extension, desktop companion, or VM isolation failures.
- Injection through HTTP, WebSocket, messaging, integration, MCP, or skill
  inputs.

Questions about hardening a normal deployment belong in a GitHub issue and
should not include secrets.
