# Contributing to NeoAgent

NeoAgent is a Node.js/Express backend with Flutter clients. Contributions are
welcome across the server, clients, integrations, skills, tests, and
documentation.

## Before You Start

- Search existing issues and pull requests before opening a duplicate.
- Use an issue to discuss large behavior changes before investing in an
  implementation.
- Keep pull requests focused. Unrelated refactors make review and regression
  analysis harder.
- Never include credentials, tokens, personal data, runtime databases, or
  private screenshots in an issue or pull request.
- Follow [GUIDELINES.md](GUIDELINES.md) for repository architecture, naming,
  security, and style requirements.

## Development Setup

Requirements:

- Node.js 20 or newer
- npm
- Flutter stable when changing a Flutter client

Install backend dependencies:

```bash
git clone https://github.com/NeoLabs-Systems/NeoAgent.git
cd NeoAgent
npm ci
```

NeoAgent stores development runtime data under `~/.neoagent` by default. Set
`NEOAGENT_HOME` to an isolated directory when you do not want development data
to share the normal runtime.

Run the backend:

```bash
npm run dev:backend
```

Run the backend and Flutter web client together:

```bash
npm run dev:stack
```

Do not commit generated runtime data or `.env` files.

## Tests

Run the smallest relevant test command while developing, then the broader suite
before submitting:

```bash
npm run test:unit
npm run test:integration
npm run test:security
npm run test:contract
npm run test:e2e
npm run test:ws
npm run test:backend
```

For Flutter changes:

```bash
cd flutter_app
flutter analyze --no-pub
cd ..
npm run flutter:test
```

Flutter web release builds are handled by the maintainer's release pipeline.

## Pull Requests

A pull request should:

- Explain the user-visible problem and the chosen fix.
- Include focused tests for changed behavior.
- Call out migrations, configuration changes, security implications, and
  platform-specific behavior.
- Update documentation when commands, settings, APIs, or user workflows change.
- Pass the repository CI checks.

Maintainers may ask to split a pull request when independent changes can be
reviewed and released separately.

## Good First Contributions

Good starting points include:

- Documentation corrections with verified commands or links.
- Focused test coverage for an existing service or route.
- Small accessibility or error-message improvements in the Flutter UI.
- A narrowly scoped messaging or integration fix with a reproducible case.
- A skill improvement that does not depend on phrase-based filtering.

Use the `good first issue` and `help wanted` labels to find work that has already
been scoped.

## Reporting Bugs

Use the bug report form and include:

- The NeoAgent version or commit.
- Host operating system and Node.js version.
- Install type and runtime profile.
- Exact reproduction steps.
- The relevant error and sanitized logs.

The app may be running on a different server from the machine where you are
filing the issue. Identify which host produced each log and redact secrets
before posting.
