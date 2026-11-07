---
name: Board Gates
description: Runs ERC, DRC, simulation, and fabrication export on a KiCad 10 project in order, then drives the fix loop until the board is GREEN.
---

# Board Gates

A board is done when `workcenter gates <project>` prints GREEN. This
skill runs the gates, reads the reports, and fixes the design until they
pass. The gates are listed in `WORKCENTER.md`; a project may add gates,
never remove one.

## When

- A board must be called done.
- A pull request changes a `.kicad_sch` or `.kicad_pcb` file.
- A human asks whether a board passes.

## Inputs

1. The project directory: one `<name>.kicad_pro` with `<name>.kicad_sch`
   and `<name>.kicad_pcb` beside it.
2. `workcenter` on `PATH`. `workcenter doctor` must report `ok` or
   `degraded`.
3. Optional `sim/*.cir` decks with `sim/*.expect.json` bounds.

## Steps

1. Run `workcenter doctor`. `kicad-cli MISSING` means the environment has
   no toolchain. Stop and report that; `install.sh` is the fix, not a
   workaround.
2. Run `workcenter gates <project> --json`. The output is 1 record per
   gate with `status`, `summary`, `details`, `artifacts`. The same data
   lands in `<project>/build/gates.json`. The run stops at the first red
   gate.
3. For a red gate, read its report before touching the design:
   - ERC: `build/erc.json`, `sheets[].violations[]`.
   - DRC: `build/drc.json`, `violations[]`, `unconnected_items[]`,
     `schematic_parity[]`. A rule named `sierra-web: ...` (or another fab's)
     is the fab's published limit, from `rules/`: the board moves to meet it,
     the rule does not. `--fab <name>` checks a fab's limits on a board whose
     design does not name one.
   - SIM: `build/sim/<deck>.log` and the `checks` block in the gate
     record.
   Each violation has `type`, `severity`, `description`, and
   `items[].pos` in millimetres.
4. Fix the design, not the rules. Edit the schematic or the board so the
   violation goes away. Changing a rule's severity or a design rule to
   silence an error needs the human's yes and 1 line in the commit
   message that names the rule and the reason.
5. Re-run from step 2. 1 fix, 1 commit, with the gate's summary line as
   evidence in the message. Loop until GREEN.
6. GREEN: fabrication outputs are in `build/fab/` (gerbers, drill, BOM,
   schematic PDF). Run `workcenter render <project>` for the schematic,
   board, 3D and per-layer images in `build/render/`, and the turning GIFs
   (`--views spin`) that `PROCESSES.md` P23 asks of a finished version. Report the gates table, the
   counts, and the artifact paths. `build/` stays out of the repository;
   images the README shows are copied into the project's `docs/`.
7. A generated design (`design.py`, see `board-design`) is fixed in the
   Python and regenerated with `workcenter design design.py --route`,
   never by editing the `.kicad_*` files.

## Common violations and the fix that addresses them

| Gate | Type | Fix |
|---|---|---|
| ERC | `pin_not_connected` | Wire the pin or place a no-connect flag on it. |
| ERC | `power_pin_not_driven` | Add a `PWR_FLAG` symbol to the net. |
| ERC | `lib_symbol_mismatch` | Update the symbol from its library. |
| DRC | `clearance` | Move the track or pad; check the net class clearance. |
| DRC | `track_width` | Widen the track to the net class minimum. |
| DRC | `unconnected_items` | Route the net or mark it with a no-connect in the schematic. |
| DRC | `schematic_parity` | Footprint or net differs from the schematic. Update the board from the schematic in KiCad, then re-run. |
| DRC | `courtyards_overlap` | Move the footprint. |
| DRC | `silk_over_copper` | Move the silkscreen text. |
| SIM | bound failed | The circuit misses the spec. Change values in the schematic, then update the deck. |

## Checks

- A gate with status `skip` on ERC or DRC never counts as done. Report
  why it skipped.
- Release candidates run with `--strict` so warnings fail too.
- The commit that fixes a violation names the violation type.
- No `build/` directory is committed.
