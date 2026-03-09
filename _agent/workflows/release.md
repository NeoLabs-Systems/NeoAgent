---
description: how to release a new version of NeoAgent
---

To release a new version of NeoAgent, follow these steps:

1. Ensure you are on the `main` branch.
2. Ensure your working directory is clean.
// turbo
3. Run the release script with the appropriate bump type:
   ```bash
   ./scripts/release.sh [patch|minor|major]
   ```

Note: This will update the version in `package.json`, create a git tag, push to origin, and create a GitHub Release with auto-generated notes.
