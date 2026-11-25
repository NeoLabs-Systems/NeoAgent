Built-in skill libraries.

Each directory is one library that installs as a single entry in the app. It
holds a `library.json` (`title`, `description`, `homepage`, `license`,
`revision`) and the skill folders, laid out like a `.claude/skills` folder:
every folder with a `SKILL.md` is a skill and the files beside it come along.
The directory name is the library id, which is also the `library` tag the
installed skills carry.

To add a library, copy the upstream skills folder here, keep its license file
next to `library.json`, and record the upstream commit in `revision`.
