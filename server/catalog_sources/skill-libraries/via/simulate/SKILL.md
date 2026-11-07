---
name: Simulate
description: Runs ngspice on the project's sim decks and checks measured values against the bounds in the matching expect file.
---

# Simulate

The SIM gate runs every `sim/*.cir` deck in the project with ngspice in
batch mode and compares printed values against `sim/<deck>.expect.json`.
A circuit meets its spec when every bound holds.

## When

- A circuit has a measurable spec: a voltage, a gain, a cutoff, a
  settling time.
- Before layout, so the values on the schematic are right before they
  become copper.

## Inputs

1. `sim/<deck>.cir`: an ngspice batch deck. It ends with a `.control`
   block that prints the values under test, then `.endc` and `.end`.
2. `sim/<deck>.expect.json`: `{ "<name>": { "min": <n>, "max": <n> } }`.
   A name is a variable the `.control` block prints as `name = value`.

## Steps

1. Export the netlist from the schematic when the deck should follow the
   schematic: `kicad-cli sch export netlist --format spice --output
   sim/<name>.net <name>.kicad_sch`. Keep the exported netlist and the
   hand-written stimulus apart: the deck does `.include <name>.net` and
   adds sources, analysis, and the `.control` block.
2. Write the `.control` block so each value under test is 1 line:
   ```
   .control
   op
   let vout = v(out)
   print vout
   .endc
   .end
   ```
   `print` writes `vout = 2.500000e+00`, which the gate parses.
3. Write `sim/<deck>.expect.json` with the bounds from the spec, not from
   the first result.
4. Run `workcenter sim <project>`. The record has `decks.<deck>.measures`
   (every printed value), `decks.<deck>.checks` (bound by bound), and
   `failures`.
5. A failed bound means the circuit misses the spec. Change component
   values in the schematic, re-export the netlist, re-run. Do not widen
   the bound to pass.
6. An `errors` list that is not empty means ngspice rejected the deck.
   Read `build/sim/<deck>.log`; the line number in the message points at
   the deck.

## A vendor's model

A part with a published model is simulated with that model, kept in the
project's `library/` and listed in `library/sources.csv` (`PROCESSES.md`
P27; `workcenter sources` checks the rows).

1. Include it by its library path from the deck, as the vendor ships it:
   `.include "../../library/ti/TLV75533P_TRANS.lib"`. The gate runs the deck
   from `build/sim/run/<deck>/` with the model translated where its row's
   `Ngspice` column says (`ps`, `res-model`, `tolerance`); never edit the
   vendor's file.
2. Check the model before trusting it: drive it at its datasheet's own
   test conditions and print each electrical-table value, and bound each
   in the expect file with the table's min and max and a `"warn"` naming
   the row: `{"min": 0.975, "max": 1.025, "warn": "the model against its
   datasheet: IOUT at VSENSE 100 mV"}`. A warn bound outside is reported,
   and fails only `--strict`; a bound without `warn` is the design's.
3. Then drive it as the board does (the board's parts, its load, its
   supply's range) with bounds from the design: a firmware constant, the
   next part's operating range.
4. Where a model is off its datasheet, the datasheet governs: say so in
   the version's README with both values, and keep the warn bound so the
   next model revision shows whether it was fixed.

## A part with no model

A part whose maker publishes no model (a MOSFET, say) is fitted to its
datasheet's table in `sim/models/`, the project's own file, which needs no
library row; the `verification` skill gives the method. Check the fit as a
vendor's model is checked: every table row a `warn` bound, the rows the
fit did not use included.

## A bound that serves a requirement

In a project with a verification package (P28), a bound names its
requirement: `{"req": "REQ-USB-05", "max": 30.0, "source": "..."}`.
`workcenter verify` checks the name exists. A requirement the design fails
gets no bound: the package's traceability table says FAIL.

## Checks

- Every bound in an expect file traces to a line in the spec or the
  schematic notes.
- A deck with no expect file still has to run clean; it proves nothing
  about the spec, and the report says so.
- `build/sim/` is not committed.
