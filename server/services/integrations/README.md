# Official integration modules

Each official integration lives in its own directory and exports exactly one
`create*Provider` factory from `provider.js`. The registry discovers these files
at startup, validates the provider contract, and rejects duplicate provider
keys. No central import or registration list is required.

A provider must expose:

- `key`, `label`, `description`, and one or more `apps`
- `getApp()`, `getEnvStatus()`, and `buildSnapshot()`
- `getToolDefinitions()` and `supportsTool()`

Connection tests are automatic when an app exposes a read-only tool without
required inputs. Providers may implement `testConnection(connection, options)`
when a dedicated identity or health endpoint is safer or more accurate.
