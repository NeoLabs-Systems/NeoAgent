# Contributing to NeoAgent

NeoAgent is a Go backend with Flutter clients. Contributions are
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

- Go (the version in `go.mod`)
- Flutter stable when changing a Flutter client

```bash
git clone https://github.com/NeoLabs-Systems/NeoAgent.git
cd NeoAgent
go build ./...
```

The shared foundation module `github.com/NeoLabs-Systems/neolabs-go` is fetched
by the Go tool. To work on both at once, clone it next to this repository and
create an untracked `go.work`:

```bash
go work init . ../neolabs-go
```

NeoAgent stores runtime data under `~/.neoagent` by default. Set
`NEOAGENT_HOME` to an isolated directory for development so it never shares the
normal runtime:

```bash
NEOAGENT_HOME="$(mktemp -d)" go run ./cmd/neoagent serve
```

Run the Flutter web client against it:

```bash
cd flutter_app
flutter run -d chrome --dart-define=NEOAGENT_BACKEND_URL=http://localhost:3333
```

Do not commit generated runtime data or `.env` files.

## Tests

Run the tests of the package you changed while developing, then everything
before submitting:

```bash
gofmt -l cmd internal
go vet ./...
go test -race ./...
```

For Flutter changes:

```bash
cd flutter_app
flutter analyze --no-pub
flutter test ../test/flutter/unit ../test/flutter/widget
```

Flutter web release builds are handled by the maintainer's release pipeline.

## Pull Requests

Open contributor pull requests against the `beta` branch, not `main`. Create a
feature branch in your fork, push your changes there, and select `beta` as the
base branch when opening the pull request. The `main` branch is managed by the
stable release workflow and receives promoted changes from `beta`.

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
- Host operating system and architecture.
- Install type and runtime profile.
- Exact reproduction steps.
- The relevant error and sanitized logs.

The app may be running on a different server from the machine where you are
filing the issue. Identify which host produced each log and redact secrets
before posting.
