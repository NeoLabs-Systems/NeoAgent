---
name: Board Design
description: Writes a KiCad 10 schematic and board as a Python design file built from the installed libraries, routes it headless, and iterates until the gates are GREEN.
---

# Board Design

The agent designs a board as code. A design file exposes `build()` that
returns a `kicadgen.Design`: parts from the KiCad libraries, nets as
names, positions on the board. `workcenter design` turns it into a KiCad
project and routes it with FreeRouting. No GUI at any step.

## When

- A new board, from a spec to fabrication outputs.
- A board change that is easier to express in Python than by hand in
  KiCad: moving a block, swapping a part, adding a channel.

## Inputs

1. A spec: what the board must do, the body it must fit, the connectors.
2. `python3 tools/kicadgen.py pins Lib:Symbol` and
   `python3 tools/kicadgen.py footprint Lib:Footprint` to read pins, pad
   numbers, and courtyards before placing anything.
3. The `attached-repos` roles: the design file lives in the project
   repository, never in the workcenter.

## Steps

1. **Pick parts from the libraries.** Check each symbol and footprint
   exists first; several common modules are not in KiCad's libraries.
   Record the choice and the reason in the project README.
2. **Write `design.py`.** One `d.add(ref, "Lib:Symbol", value, "Lib:Footprint",
   sch_at=(x, y), pcb_at=(x, y), nets={pin: net})` per part. Rules:
   - Power nets go in `d.power_nets` and get power symbols. Nets with no
     power-output pin (GND, VBUS from a connector) go in `d.flagged_nets`
     for a PWR_FLAG. A net that already has a power-output pin must not be
     flagged: two drivers is an ERC error.
   - Stacked hidden connector pins (USB-C VBUS A4/A9/B4/B9, GND A1/B1/A12/
     B12) all need the net, or their pads stay open.
   - Every unused pin is left out of `nets`; the generator places a
     no-connect and names its pad net the way KiCad does, so parity passes.
   - Schematic positions on the 1.27 mm grid, as multiples of 2.54.
   - **The schematic is a drawing someone reads** (P24). Set `d.sch_wires =
     True`: the generator draws wires between the pins of each net round the
     parts, a junction dot at each tee, every power pin's symbol pointing away
     from its part, and each net's name once along its wire. Without it every
     pin gets a stub and a label and nothing is joined on the page. Lay the
     parts out in blocks the way the signal flows, power left to right
     along the top, as a schematic in a service manual does: keep a table
     `SCHEMATIC = {ref: (x, y, angle)}` in 2.54 mm steps and apply it after
     the parts are added (`part.sch_at`, `part.sch_rot`). `sch_rot` turns a
     symbol 90, 180 or 270 degrees counter-clockwise, as KiCad shows it: a
     resistor at 90 has pin 1 on the left. Turn two-pin parts so the end
     that joins a wire faces it, put each decoupling or pull part beside the
     pin it serves, and let a connector face the circuit it feeds.
     `d.sch_label_nets` keeps labels for nets that cross the whole sheet;
     a pin no wire reaches gets a label by itself. `d.sheet` picks the paper
     (A4 to A1). The generator raises on a pin off the grid, two pins on one
     point, or a pin whose first cell out is taken: move the part. Plot the
     sheet (`workcenter render . --views schematic`) and read it before the
     close-out.
   - Pulls (P16 step 5): `d.check_pulls = True` makes `workcenter design`
     fail on a control input that can float in reset: a gate, a logic
     input, a switch or an I2C line that no output drives and no resistor
     holds at a rail (or a gate at its own source). Every design prints these
     as `pull:` lines. A net held elsewhere goes in `d.defined_nets` with the
     reason: `{"BTN": "PB7's internal pull-up, set in firmware gpio.c"}`,
     `{"I2C_SDA": "4.7k to 3V3 on the display board, R4"}`.
   - `d.net_classes` for heavy nets. The widest track that enters a pad is
     the pad pitch minus the pad width minus 2 x clearance: 0.6 mm for
     SOT-23 and 0603, 0.5 mm for 0402, 0.4 mm for TSSOP. Put the ADC sense
     pin behind a series resistor so it is not on the heavy net; a sense
     tap may be drawn thinner than its class with `width=` on `d.track`.
   - `pcb_layer="B.Cu"` puts a part on the bottom face. The generator
     mirrors it the way KiCad does. On the back face a part at rotation 0
     has its pad 1 on the left and its pads' y mirrored: a SOT-23 has gate
     bottom-left, source top-left, drain right. Read positions from a DRC
     report (`workcenter drc`) rather than from memory before hand-routing
     to a back-side pad.
   - `corner_radius=` on `Design` rounds the board corners; the outline becomes
     four lines and four arcs, the router's boundary and the default pour
     follow them, and the via check knows the corners. Pads near a corner
     need `edge_clearance` from the arc, not from the rectangle. Half the
     short side makes a stadium (round ends, two arcs meeting). Four radii,
     `(top-left, top-right, bottom-right, bottom-left)`, give each corner its
     own: `(6.35, 1.0, 1.0, 6.35)` rounds the left end into a half circle and
     leaves the right end flat for a board that stands on it; 0 is a square
     corner.
   - `thickness=` on `Design` sets the finished board (1.6 mm unless told
     otherwise); any other value writes a stackup, on two layers too. A
     daughter board soldered upright on another is often 0.8 mm. Say it in
     the README's fab notes.
   - A part the library lacks gets a project footprint: a `.pretty` folder
     in the project, named in `d.footprint_dirs = {"Name": path}` and used
     as `"Name:Footprint"`. Read it with
     `python3 tools/kicadgen.py footprint --lib Name=path Name:Footprint`
     before placing; the generated project gets an `fp-lib-table` for it.
   - A symbol the library lacks, or draws only in several units (a dual
     MOSFET: the generator places one unit per part), gets a project symbol:
     a `.kicad_sym` file in the project, named in
     `d.symbol_dirs = {"Name": path}` and used as `"Name:Symbol"`, one unit
     with every pin. Read it with
     `python3 tools/kicadgen.py pins --lib Name=path Name:Symbol`; the
     schematic embeds it and the project gets a `sym-lib-table`.
   - `d.keepout(d.circle(cx, cy, r), layers=("F.Cu",), name="collar")` keeps
     tracks and vias out of an area (under grounded metal, a mounting
     screw, an antenna). KiCad gets a rule area, the router a keepout, and
     the generator's own vias stay out of it.
     A keep-out's via ban holds on every layer, since a via passes them
     all: a part placed inside one is wired out on its own face to a via
     outside (the strips along the board edges, past the keep-out circle).
     `workcenter design` lists every hand via that lands in a keep-out or
     on any face's pad, and exits 1.
   - The fab, before anything is placed: `d.fab = "sierra-circuits-web"`
     (or another set in `rules/`) writes its limits into the project as
     `<name>.kicad_dru` and raises the board's own minimums to its
     board-wide ones, so the via check below and the DRC hold the board to
     what the fab can make. Sierra's Web PCB wants a 6 mil (0.1524 mm) ring,
     so the workcenter's 0.6/0.3 mm via does not do (0.65/0.3 does), 5 mil
     legend text (`d.text(..., thickness=0.13)`), and 13 mil from every
     hole to inner-layer copper.
   - Via sizes (`via_size`, `via_drill`, each net class's `via` and
     `via_drill`, any hand via) must meet the board's rules: a 0.3 mm hole,
     a 0.5 mm via, a 0.1 mm ring unless `d.rules` lowers them or the fab
     raises them.
     `workcenter design` lists every size the rules refuse and exits 1,
     before routing (P3 step 5, M46).
   - `d.model(ref, "${KIPRJMOD}/models/x.wrl")` gives a part a 3D body for the
     renders and the STEP export when the library has none (vertical
     receptacles, wire pads with a stud). `python3 tools/wrlgen.py` writes
     parametric bodies (`usb-c-vertical`, `threaded-stud`) in KiCad's VRML
     units; keep them in the project under `models/` with the command that
     made them.
   - KiCad's library footprints name 3D bodies its 3D library does not ship
     (QFN-28 4 x 4 mm without a pad, DFN-8 3 x 2 mm, SOT-523): those parts
     render as bare pads. `workcenter render` names each one ("parts drawn
     without a 3D body"); give each a body with `wrlgen leadless` (QFN, DFN,
     SON) or `wrlgen gullwing` (SOT-23, SOT-523, SC-70) sized from the
     package drawing, attached with `d.model(ref, path, replace=True)`.
   - A model's rotation in KiCad 10 turns each axis the opposite way from
     the right-hand rule, about the footprint's fixed axes, x before z; its
     offset has y up. A board exported with `kicad-cli pcb export vrml`
     lies with y up its face and z out of it: (-90, 0, -90) stands it on
     edge with its face along +x, (90, 0, 90) hangs it below the board
     (M42, M47). Render once before composing views (P7 step 4).
   - `d.text(label, x, y, "F.SilkS", size, thickness)` for contact labels.
     Below 0.8 mm text, set `d.rules = {"min_text_height": ..,
     "min_text_thickness": ..}` or the DRC flags every label.
   - `d.zone("GND", layers=("F.Cu", "B.Cu"), connect="solid")` for a
     ground pour on both faces. The router treats it as a plane and routes
     no ground track; KiCad fills it when the design is written. Prefer
     solid connections on a dense board: thermal spokes get starved
     between 0402 pads and the DRC reports each one.
   - Four layers, when two cannot route the board: `copper_layers=4` on
     `Design` (set it first; tracks, zones and keepouts check their layer
     against it) adds `In1.Cu` and `In2.Cu` and a 1.6 mm stackup. A ground
     plane is `plane_layers=("In1.Cu",)` with `d.zone("GND",
     layers=("In1.Cu",), connect="solid")`: no track goes there, the router
     never sees it, and KiCad clears every other-net via when it fills it.
     Every through pad and via of the net lands on the plane, so each top or
     bottom island needs one via, and a face pour can be cut freely. The
     other inner layer routes like a face. Say in the README that the fab
     order is four layers; it costs more than two.
3. **Place.** Keep courtyards apart; read them with the `footprint`
   command. Group by current: heater copper short, connectors at edges,
   decoupling beside the IC on the same face as its pins. Rotate with
   `pcb_rot`, 90 degrees at a time. Leave the router room: 0402 columns
   2.3 mm apart let one track pass, rows 1.7 mm apart let a via sit between
   them. A TSSOP's pads block its sides; signals reach them from under the
   body or from the row ends.
4. **Generate and check.** `workcenter design design.py` then
   `workcenter erc .` and `workcenter drc .`. Fix every error except
   unconnected items before routing. Courtyard overlaps and pad clearance
   are placement mistakes the router cannot fix. Then, for each IC whose
   parts moved, `workcenter placement placement_audit . --ic U1` and
   `workcenter placement route_check . --ic U1` (kistack's checks; the
   `kistack` skill and its layout-placement guide say what to fix first).
5. **Route.** `workcenter design design.py --route --passes 60`. The
   command prints what the router did and which ground pads ended up on an
   island; `workcenter drc .` lists what stayed unrouted. FreeRouting
   stops early when it decides a connection cannot be made; more passes do
   not help. For each one left:
   - A width that cannot enter a pad, a crowded region, or a board too
     small: change the design, not the router settings.
   - A link the router could not find but a person can: draw it with
     `d.track(net, [(x, y), ...], layer)` and `d.via(net, x, y)` at the
     end of `build()`. The router keeps hand-routed copper and routes
     around it. Draw the heavy loop first (battery feed, heater return),
     then the taps and gate drives, one net at a time, with
     `workcenter drc .` between rounds: the DRC names the pad or track
     each slip touches. End tracks on pad centres. A part moved in the
     same change is regenerated and its pads read before its tracks are
     written. A long hand route is a wall on its layer: list the pads it
     cuts off from their nets first, and move a part rather than draw a
     lane that leaves one with no way in.
   - A ground pad cut off from the pour: the design command already
     routes again with a via reserved beside it (`--rounds`); if it still
     reports the island, move the walling track or the part.
   - Pours split into halves (a column of tracks across the board on both
     faces): keep a ground corridor, a `d.keepout` strip along one edge of
     one face with tracks and vias forbidden and the pour allowed. The pour
     then runs end to end on that face and every island on the other face
     can be stitched to it.
6. **Gates.** `workcenter gates .` until GREEN. `workcenter render .` for
   the images: schematic, both faces, 3D top, bottom and isometric, and every
   layer on its own (`layers/`, `layers.png`); `--views spin` adds a GIF of
   the 3D board turning round, which a finished version carries for every
   board and its assembly (`PROCESSES.md` P23). Commit
   `design.py`, any `models/*.wrl`, and the generated `.kicad_*` files
   together; the generated files are what KiCad opens.

## Checks

- `python3 tools/kicadgen.py pins` was run for every symbol with more than
  2 pins before nets were assigned.
- ERC: 0 errors and 0 warnings. Library-table warnings are suppressed in
  the generated project because every symbol and footprint is embedded.
- The schematic is wired (`sch_wires`) and its plot was read; DRC shows no
  parity warning (each wired net carries its own name).
- `workcenter render` names no part drawn without a 3D body.
- DRC: 0 errors. Silkscreen warnings near board edges are acceptable;
  clearance and courtyard warnings are not.
- The design file is the only hand-written source; nobody edits the
  generated KiCad files. Hand-routed copper lives in `build()` too.
- The README names each part choice and the reason, and lists every
  external contact with its net, pad and position.
