---
title: Licensing decision
sidebar_label: Licensing
description: Why NeoAgent stays on AGPL-3.0-only, and what MPL-2.0 would change.
---

# Licensing decision

**NeoAgent is licensed under the GNU Affero General Public License version 3 only (`AGPL-3.0-only`), and stays there.**

## 📄 Where it is declared

| File | Declares |
| --- | --- |
| `LICENSE` | The full GNU Affero GPL v3 text |
| `package.json` | `"license": "AGPL-3.0-only"` |
| `README.md` | AGPL-3.0-only, linking to this page |

The `LICENSE` file once held the plain GPLv3 text instead of the Affero text; that mismatch is fixed.

## ⚖️ Why AGPL

- **NeoAgent is a network service.** People mostly use it through a server, not a copy on their own machine.
- **Network reciprocity.** Anyone who runs a modified NeoAgent for others over a network must offer those users the source.
- **Improvements stay open.** Changes to deployed NeoAgent servers stay available to their users and the community.

## 🔍 AGPL-3.0-only compared with MPL-2.0

| Consideration | AGPL-3.0-only | MPL-2.0 |
| --- | --- | --- |
| Copyleft scope | Whole program | Per file |
| Modified hosted service | Must offer source to network users | Hosting alone triggers nothing |
| Separate proprietary files | Generally constrained when part of the program | Allowed in a larger work if kept in separate files |
| Patent grant | Included | Included |
| Warranty disclaimer | Included | Included |

MPL-2.0 would make commercial embedding and proprietary extensions easier, but it drops AGPL's network-use source requirement.

## 🧾 If this ever changes

- **Not a fix for other obligations.** A new license leaves copyright, provenance, patent, trademark and dependency obligations in place.
- **Needs every holder's consent.** Relicensing existing code requires the rights from its copyright holders.
- **A separate project.** Moving to MPL-2.0 would be its own relicensing effort, taken on only if commercial integration ever outweighs network reciprocity.

:::note Not legal advice
- **A project decision.** The binding terms are in the root `LICENSE` file.
- **Primary references.** Mozilla's [MPL 2.0 FAQ](https://www.mozilla.org/MPL/2.0/FAQ/) and the GNU Project's [explanation of the Affero GPL](https://www.gnu.org/licenses/why-affero-gpl.html).
:::
