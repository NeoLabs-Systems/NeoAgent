Bundled skill sources for the NeoAgent store.

These files are kept as local install sources so the store can install bundled
skills without depending on runtime network access. Every directory containing
a valid `SKILL.md` is discovered automatically. Add `catalog: false` to the
file's frontmatter only when the source must remain available without appearing
in the store.
