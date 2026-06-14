# Development and testing

Read
[GUIDELINES.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/GUIDELINES.md)
before changing code. It defines module boundaries, security requirements,
naming, and project-specific constraints.

## Setup

```bash
git clone https://github.com/NeoLabs-Systems/NeoAgent.git
cd NeoAgent
npm ci
npm run dev:backend
```

Use a separate `NEOAGENT_HOME` when development data must not share the normal
installation.

Run the backend and Flutter web development client with:

```bash
npm run dev:stack
```

Do not run a Flutter web release build during normal development. The release
pipeline and maintainer own that artifact.

## Server conventions

- Keep Express routes limited to request parsing and response handling.
- Put business logic in domain services.
- Use CommonJS and start new server files with `'use strict';`.
- Route all database access through the shared database module.
- Route all model calls through the AI engine and provider layer.
- Use runtime path helpers and the shared logger.
- Validate external and user-supplied data at system boundaries.

## Tests

Run the smallest relevant suite while working:

```bash
npm run test:unit
npm run test:integration
npm run test:security
npm run test:contract
npm run test:e2e
npm run test:ws
```

Run the complete backend suite before submitting:

```bash
npm run test:backend
```

Flutter changes use:

```bash
cd flutter_app
flutter analyze --no-pub
cd ..
npm run flutter:test
```

Documentation changes use:

```bash
npm run docs:build
npm run docs:dev
```

The Docusaurus build treats broken routes as errors. Check both desktop and
narrow layouts after changing navigation, tables, or images.

## Contributions

Contributor pull requests target `beta`. Keep changes focused, include tests
for behavior changes, document new commands and settings, and never commit
runtime data or credentials. See
[CONTRIBUTING.md](https://github.com/NeoLabs-Systems/NeoAgent/blob/main/CONTRIBUTING.md).
