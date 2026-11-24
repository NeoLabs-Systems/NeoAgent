---
name: Procurement
description: Turns a board's schematic into an orderable parts list - a real part, supplier number, price breaks and stock for every line, items off the board too - and totals the cost for a number of units.
---

# Procurement

A board is not buildable until every line of its BOM names a part someone
can order. This skill finds those parts, records them in a parts file, and
runs `workcenter procure` for the priced list and the totals.

## When

- A human asks what a board costs, for its parts list, or to order parts.
- A new version adds or swaps a part.
- A parts file's prices are older than 90 days (`procure` lists them).

## Inputs

1. The project: a schematic, and the README's notes on each part's ratings.
2. `workcenter procure` (`workcenter doctor` shows `kicad-cli`).
3. A parts file, `parts.csv`, kept with the project. Columns:

| Column | Holds |
|---|---|
| `Value` | The schematic's value, as the BOM groups it |
| `Footprint` | The schematic's footprint, library and name; empty for an item off the board |
| `Qty` | Off the board only: how many per unit |
| `Manufacturer`, `MPN` | The part |
| `Supplier`, `SKU` | Where to buy it and its number there; `none` for a line that is copper on the board (a pad), nothing to buy |
| `Pack` | Order in multiples of this (a PCB fab's set of 3); empty is 1 |
| `Breaks` | Price breaks as the page shows them, `1:0.10 10:0.021 100:0.0097`, USD per unit |
| `Stock`, `Checked`, `URL` | Stock on the page (0 when it says out of stock), the date read, the page |
| `Note` | Rating, packaging, backorder date, why this part |

## Steps

1. Run `workcenter procure <project> --parts parts.csv --boards 1,10`. With an
   empty parts file it lists every BOM line under "Not in the parts files":
   that is the list to fill.
2. For each line, choose the part before looking it up (P25 step 3): one part
   per value and footprint that meets the strictest use on every board that
   names it, read from the design's notes (a 4.7 µF on a 5 V input needs
   10 V; a shunt rated for the heater's current).
3. Look it up the sanctioned way (P25): the supplier's API with the user's
   own credentials, or its product page with the fetch tool where robots.txt
   allows it (Digi-Key allows Claude-User). Find the page by search; confirm
   the manufacturer part number printed on it; read the cut tape or bulk
   packaging's breaks and stock. A plain script that gets a 403 has been
   refused: never retry it disguised.
4. Write the row as the page shows it, with the date and URL. Out of stock
   stays 0, its expected date in the note. A part the supplier does not
   carry gets the supplier that does (LCSC for many Chinese parts), or no
   price and a note saying where it was looked for. Never a part with
   another footprint in place of the designed one.
5. Items off the board are rows with no footprint and a `Qty` per unit: the
   cell, connectors and cartridges the schematic does not carry, the bare
   boards (a fab's published price per area, `Pack` 3 for sets of three),
   tape, vents. Copper the BOM lists (wire pads, joint pads) is `Supplier`
   `none`.
6. Run `procure` again and read `build/procure/parts.md`: the lines, the
   cheapest order per line, the totals per supplier, and the lists "Not
   priced", "Short of stock" and "Prices to check again".
7. Keep `parts.csv` with the project and copy `parts.md` where the project
   keeps its documents; the report names the totals and every line in the
   three lists.

## Checks

- Every priced row has a URL and a date it was read; no price came from
  memory or a search snippet.
- Every BOM line is matched; `Supplier` `none` only for copper.
- The report says what the totals leave out: shipping, tax, assembly, and
  anything listed under "Not priced".
