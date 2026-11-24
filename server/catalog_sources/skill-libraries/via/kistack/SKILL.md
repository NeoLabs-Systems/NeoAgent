---
name: kistack
description: Routes an agent to the vendored kistack KiCad skills (placement, layout, schematic, BOM, footprint, symbol, export, Gerber review, panelize) at the step where each helps, runs kistack's placement checks headless with `workcenter placement`, and says where this workcenter's rules override kistack's.
---

# kistack in the workcenter

`third_party/kistack/` holds American Embedded's kistack skills, pinned to one
commit (`third_party/kistack/VENDORED.md`). They are a second opinion written by
people who lay out boards for a living: read the one for the step you are on and
use its checklist and its reasons. They were written for an agent driving a live
KiCad through Backplane; this workcenter builds boards from `design.py` and runs
headless, so some of their mechanics do not apply here. The overrides below say
which.

## Which skill, when

| Step | kistack file | What to take from it here |
|---|---|---|
| Placing parts in `design.py`, before the first route | `skills/layout-placement/SKILL.md` | The order (what tolerates least distance goes first), the decoupler, regulator, crystal and RF rules, the reachability rules. Then run its checks: `workcenter placement placement_audit <board> --ic U1`, `route_check <board> --ic U1`, `pin_sides <board> U1`, `local_search <board> C3 --conflicts`, `group_search <board> ...`. One IC per run. |
| Routing and stitching | `skills/layout/SKILL.md` | Return paths, via stitching, dead copper, connector access. |
| Reviewing a routed board | `skills/pcb/SKILL.md` | DRC with kicad-cli, layer renders (`workcenter render`), 3D-model interference. |
| Drawing or reviewing a schematic | `skills/schematic/SKILL.md` | Power symbols up, ground down; passives wired to their pins; datasheets as the source of truth; check the schematic as images. |
| Choosing or checking parts | `skills/bom/SKILL.md` | Capacitor DC-bias and dielectric derating, resistor power, inductor saturation and DCR, MPN fields in the schematic. Prices and stock still come from the `procurement` skill. |
| A footprint KiCad does not have | `skills/footprint/SKILL.md` | Describe the land pattern in words from the datasheet before writing it; prefer kicad-library-tools' generators to a hand script. |
| A project symbol | `skills/symbol/SKILL.md` | KLC: inputs left, outputs right, power top, ground bottom; check pins against the datasheet's table. |
| Fabrication outputs | `skills/export/SKILL.md` and its `references/` | The kicad-cli command reference; `scripts/convert_position.py` for JLCPCB/NextPCB placement files. |
| Looking at the Gerbers | `skills/gerbers/SKILL.md` | Render each layer and look for shorts and colliding vias. The venv has pygerber 2.4.3, whose command is `pygerber raster-2d build/fab/gerbers/<layer> -o <png> -d 1000 -s copper_alpha`, not the 3.x `pygerber gerber convert png` the skill names. |
| A panel | `skills/panelize/SKILL.md` | KiKit settings. KiKit is not installed here; say so rather than install it unasked. |
| Product photos | `skills/pcb-product-render/SKILL.md` | Needs Blender, which is not installed. |

## Where the workcenter wins

These override the kistack text wherever the two disagree:

1. **Never get around a site's bot protection.** `skills/schematic/SKILL.md` says to "find ways
   around" it when a datasheet download is blocked. Here that is refused: use the supplier's API, a
   page the fetch tool may read, or ask the user (P25, M55, `SECURITY.md`).
2. **The design file is the source of truth.** kistack edits the open board through the IPC API
   and saves it in place (`move.py --save`, `SaveDocument`). A generated board is never edited:
   put the new position, rotation or side in `design.py` and run `workcenter design` again.
   `workcenter placement move` refuses for this reason.
3. **No Backplane.** `.backplane.json`, `viewer_show` and Backplane's KiCad servers do not exist
   here. The stand-in reader (`tools/kistack_board.py`) reads the board file named on the command
   line; there is no "configured board" check to pass.
4. **FreeRouting routes.** `skills/layout/SKILL.md` prefers routing by hand. Here the router routes
   and the design file hand-routes only what the router cannot (P1 for the pad geometry first).
5. **The gates decide done.** kistack's "ask the user to OVERRIDE" for a failed DRC does not apply:
   a red gate is fixed, not overridden (`board-gates` skill).
6. **Parts are not chosen unasked**, as kistack says too; in this workcenter a part change also
   follows P20 (what the old part did, not only its ratings).

## What the placement checks assume

They are kistack's, unchanged: a heuristic grid router on the outer copper only, one value each
for track width, clearance, via and edge clearance (the strictest on the board), local links on the
top face. Their own SKILL.md section "What the checks assume" holds. A 4-layer board is checked as
its outer layers; a board with a `.kicad_dru` needs `--track --clear --via --edge`. A pass is not a
route and a failure is not proof that the board cannot be routed.

## Done when

- The kistack file for the step was read, and anything taken from it or set aside is named in the
  change's notes (README decisions, PR body).
- For a placement change: `workcenter placement placement_audit` and `route_check` ran on every IC
  whose parts moved, and their worst finding is fixed or stated.
