---
name: verification
description: Writes a board version's verification package (PROCESSES.md P28) - requirements from expected and unexpected conditions with sources and inspection clauses, a block diagram with a caption per mode, one writeup per ngspice deck with cited nodal analysis, calculations, and a traceability table that `workcenter verify` checks against a fresh run.
---

# Verification package

A verification package says what a board must do, under which
conditions, and the evidence that it does, so that an engineer can check
every number without trusting the author. `workcenter verify <project>`
checks it: the structure, every requirement's source and row, every
deck's writeup, and every quoted number against a fresh ngspice run.

## When

- The user asks for requirements, a review, an inspection, a "mil-spec"
  or DO-160 style check, or proof that a design meets its parts' ratings.
- Before a version is called ready for anything beyond the bench.
- After a part swap (P20) or a new feature, for the circuits it touches.

## The package

```
<project>/verification/
  README.md                 the index, the verdicts, each FAIL and its fix
  requirements/README.md    profile, conditions, the requirements table, the standards as read
  system/README.md          the block diagram and a caption per mode, the frequencies
  system/block-diagram.svg
  simulations/<name>/README.md   one per circuit; names its sim/<deck>.cir
  calculations/README.md    what no deck measures
  traceability.md           one row per requirement: check, evidence, measured, verdict
```

`workcenter verify <project> --init` writes this skeleton from
`templates/verification/` and a writeup per deck. Every `<!-- fill ... -->`
fails the check until it is written.

## Steps

1. **Profile.** Write what the device is for, how it is used, where it
   goes, and what it must never do. Ask the user for what only they know
   (the use, the environment); write the rest from the design.
2. **Conditions.** List every expected condition with its range and
   source, then every unexpected one with what the board must do
   (survive, stop, ignore). Use the checklists below.
3. **Requirements.** One row per limit:
   `| ID | Requirement | Limit | Source | Method | Inspection |`.
   - ID `REQ-<AREA>-<NN>`.
   - Limit is a number with a unit.
   - Source is the datasheet table or figure with its revision, the
     standard's clause, or the firmware's constant. Never "typical
     practice".
   - Method is analysis, simulation, examination, demonstration or test
     (MIL-STD-961E 5.9.1, simulation named apart).
   - Inspection names the clause an inspector would use, or
     "none: functional".
4. **Worst case.** Every limit is checked at the datasheets' corners, not
   their typicals: the minimum and maximum rows, the supply's range, the
   temperature range, the tolerance of every resistor that sets a value.
5. **Decks.** One deck per circuit question, in `sim/`. Each bound in
   `sim/<deck>.expect.json` that holds carries `"req": "<ID>"`. A
   requirement the design fails gets no bound (the gate stays the
   definition of done); its row in the traceability table says FAIL. A
   proposed fix may run beside the as-built circuit in the same deck, as
   its own instance, so the package measures the fix too.
6. **Models.** A vendor's model is used as P27 says. A part whose maker
   publishes none is fitted (below) and checked row by row.
7. **Writeups.** One `simulations/<name>/README.md` per circuit with the
   headings Purpose, Circuit, Inputs, Outputs, Expected, Results, "Why it
   is required, and what is not", Nodal analysis, Sources, Re-run.
8. **Calculations.** Everything no deck measures: the charge current and
   time, each part's temperature, the standby budget, the energy per use,
   environmental effects. The same rules: numbered equations, each with
   its source.
9. **System.** Draw the block diagram (SVG; every net by its design name;
   colour the charge path, the load path, logic, sensing, return). Write
   one caption per mode: where the charge comes from, which path it takes,
   which parts conduct, which are off, what ends the mode. List every
   frequency on the board with its source.
10. **Traceability.** One row per requirement:
    `| ID | Check | Evidence | Measured | Verdict |`. Check is
    `deck.meas <= 30 V` or `3.0 V <= deck.meas <= 3.6 V`; `verify`
    recomputes it and the verdict must agree. PASS, FAIL or OPEN (no
    evidence yet).
11. **Run** `workcenter verify <project>` until it reports no problems.
    A FAIL is a finding, not a problem: report it with its size and the
    proposed fix; a fix that changes the board is a new version (P22).

## Citation rules

- Each equation names its source next to it: "(SLUSCE2D 7.5, KISET)",
  "(DS14693 Rev 2 Table 21 note 3)", "(KCL at HS)", "(the series RLC step
  response)", "(Grover, a rectangular conductor's inductance)",
  "(IPC-2141 microstrip)", "(UM10204 Rev. 7.0 7.1, equation 1)".
- A datasheet is cited by its document number and revision, and the
  table, figure or section. Read the section number from the PDF's text
  (`pdftotext -layout`), never from memory.
- A standard is cited by edition and clause, and the package says where
  it was read. A standard the publisher sells is read through a public
  source that reproduces the clause (an application note, a regulator's
  advisory circular), and the package names that source.
- A value with no published source (a cell with no datasheet, a cable) is
  an assumption: say so where it is used, and give a corner.
- A number in a Results table is quoted to the digits the run supports:
  `verify` compares it to half a unit of its last digit, with SI prefixes
  (`4.7 mV`, `125 ns`, `22.19 mOhm`, `7.22 nC`).

## Nodal analysis

- Draw the circuit as the deck models it, then solve it by hand: the DC
  operating point by KCL and KVL; switching as RC, RLC and gate-charge
  intervals; transients as step responses with their damping ratio and
  overshoot.
- For a MOSFET, use its square law where it matters:
  `Id = Kp/2 (Vgs - Vth)^2` in saturation, `gm = sqrt(2 Kp Id)`, the
  Miller plateau `|Vgs| = |Vth| + sqrt(2 Id / Kp)`; a gate current through
  a resistor sets how long the plateau lasts (`Qgd / Ig`), and so the
  di/dt and the inductive spike.
- Compare every hand result with the deck's and explain the difference.
  A difference of more than a few percent is a finding about the model or
  the algebra.

## Conditions to walk through

- **Power in**: each source class the port can meet (for USB: USB-C
  without PD, with PD, BC1.2, a computer's port before and after
  configuration, a low-power port), at its range's ends, through a long
  and a short cable; a live plug; a faulty source up to the next
  standard voltage (20 V for USB PD) and up to the input part's rating.
- **Every pin a source reaches**: the ADC divider, the capacitor's rating,
  the data lines; an MCU's 5 V-tolerant pin may take no positive
  injection and less in analog mode.
- **Loads**: each load's range and its fault (short, open, partial);
  the switch's edges, the supply's ring, the sense path's settling at the
  ADC's sample.
- **The cell**: its range, its protection's thresholds at their worst,
  warm; charging outside its temperature range.
- **Standby**: every part's current in the sleep mode the firmware uses,
  from its datasheet table, against the shelf time the user expects.
- **Environment**: temperature, pressure changes (a sensor that reads
  pressure sees a decompression), ESD, drop, vibration, emissions.
- **Firmware**: a hang, a reset, the limits the hardware relies on.

## Fitting a model to a datasheet

When the maker publishes no SPICE model (a MOSFET, say):

1. Use an ngspice VDMOS model in `sim/models/`, the project's own file;
   the SIM gate needs no library row for a model under the deck's folder.
2. Fit from two table rows: the on-resistance is
   `Rd + Rs + 1 / (Kp (|Vgs| - |Vto|))`, so two RDS(on) rows give Kp and
   Rd + Rs; Vto is the datasheet's VGS(th). Set `Ksubthres` near 0.02 V:
   ngspice's default of 0.1 V moves the 250 µA threshold point by about
   0.3 V.
3. Fit the capacitances to Ciss, Coss, Crss at the test voltage and to
   the gate-charge figure: Cgs about Ciss - Crss, Cgdmax from the slope of
   the gate-charge curve after its plateau. Three numbers and three
   parameters: sweep them in ngspice.
4. Make a maximum-column model the same way, and check it stays at or
   under the maximum at the rows' own currents. Away from those currents
   it is no maximum: a worst case takes the nearest maximum row as flat
   (M83).
5. Check every row in a deck (`sim/mosfets.cir` style) with warn bounds,
   including rows the fit did not use. Say what the fit leaves out
   (temperature, avalanche, gate ESD diodes) and use the datasheet's
   rows where those matter.

## Standards map

DO-160G is written for airborne equipment; for a device carried on board
its clauses serve as the inspection pattern, by analogy. Clauses as read
for the first package (Last Hit v0.14, `verification/requirements/`):

| Concern | DO-160G | MIL-STD-461G / 810H | Other |
|---|---|---|---|
| Supply input range, abnormal input | 16 Power Input | — | USB 2.0 Table 7-7 (+2014 ECN: 5.50 V); USB PD 3.0 Table 7-24 (vSafe5V) |
| Transients, a live plug | 17 Voltage Spike | 461G CS116 | — |
| Electrostatic discharge | 25 Electrostatic Discharge | 461G CS118 | IEC 61000-4-2 (levels, 150 pF / 330 Ohm); JS-001 HBM |
| Temperature, altitude, decompression | 4 (4.6.2), 5 | 810H 500.6, 501.7, 502.7, 503.7 | — |
| Humidity | 6 | 810H 507.6 | — |
| Shock, drop, vibration | 7, 8 | 810H 516.8, 514.8 | — |
| Emissions | 21 | 461G CE102, RE102 | — |
| Derating | — | — | NASA EEE-INST-002: ceramic capacitors 60 % of rated voltage (C1 Table 4); power MOSFETs VDS 75 %, VGS 60 %, Tj 125 °C or 40 °C under the maximum (S1 Table 4) |
| Lithium cells, vaping devices | — | — | IEC 62133-2; UL 8139 |
| I2C | — | — | UM10204 Rev. 7.0 Table 10 (VOL, Ci), Table 11 (tr, Cb), 7.1 |

Newer editions exist for several (IEC 61000-4-2 Ed. 3.0, MIL-STD-461H,
UL 8139:2024, DO-160H planned); name the edition read.

## Traps found so far

- A part swap changes figures far from the swapped part: the STM32G031's
  few µA of Stop became the C071's 85.5 µA, and the README kept "50 µA".
  Recompute every budget the part enters (P20).
- "Typical" is not a limit: the charger's 0.4 W was at 5.0 V and a
  3.0 V cell; the corner (5.5 V, 2.8 V, the ISET tolerance) is 0.6 W.
- A vendor model can be wrong where it matters (TI's TLV75533P drops a
  fixed 123 mV where the datasheet says 12.9 mV at 30 mA). Bound the
  model against its datasheet and let the datasheet govern.
- A hard short's current is set by the cell's own resistance, not the
  coil: it may not reach the protection's short-circuit threshold.
- ngspice: a `.control` `meas` cannot take `v(a,b)` or `par()`; compute
  a vector with `let` first. A step into a capacitor through a switch
  can stop the trapezoidal rule at the first step: `.options
  method=gear`. Run a deck that includes a PSpice model through the gate,
  which sets its mode before parsing. `let` takes no SI suffix (`37e-3`,
  not `37m`). Each analysis starts a new plot, and a `meas` result lives
  in the plot it was measured in: compute what needs it right after the
  `meas`, before the next `tran` (M78).
- A corner named in a bound's `source` is built into the circuit the bound
  reads: its own source, its own part values (M80).
- A stand-in model that clamps at a part's absolute maximum hides the
  violation it should show: an open drain emptying a 10 nF hold capacitor
  asked 70 mA of a 10 mA pin. Measure every output's peak current into
  what it drives and bound it with the rating (M81).
- A limit computed from parts' values takes their tolerances, as the
  design's own numbers do (M82).

## Done when

`workcenter verify <project>` reports no problems, every FAIL has its
size and a proposed fix in the package's README, and the report to the
user names the counts of PASS, FAIL and OPEN.
