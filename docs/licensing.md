# Licensing decision

NeoAgent remains licensed under the **GNU Affero General Public License
version 3 only** (`AGPL-3.0-only`).

The package metadata and README already declared AGPL-3.0-only. The repository's
`LICENSE` file contained the standard GPLv3 text instead of the Affero GPLv3
text; that inconsistency has been corrected.

## Why retain AGPL

NeoAgent is primarily a networked, self-hosted service. AGPLv3 requires an
operator who modifies the program and makes that modified version available to
users over a network to offer those users the corresponding source. That
reciprocity matches the project's goal of keeping improvements to deployed
NeoAgent services available to their users and the community.

The Mozilla Public License 2.0 is a weaker, file-level copyleft license. Changes
to MPL-covered files remain under the MPL when distributed, while separate new
files can be combined into a larger work under different terms. That can make
commercial embedding and proprietary extensions easier, but it does not provide
AGPL's network-interaction source requirement.

| Consideration | AGPL-3.0-only | MPL-2.0 |
| --- | --- | --- |
| Copyleft scope | Program-level | File-level |
| Modified hosted service | Must offer corresponding source to network users | Hosting alone does not trigger source distribution |
| Separate proprietary files | Generally constrained when part of the covered program | Permitted in a larger work when kept in separate files |
| Patent grant | Included | Included |
| Warranty disclaimer | Included | Included |

## Legal-risk considerations

Changing licenses does not remove copyright, provenance, patent, trademark, or
third-party dependency obligations. Relicensing existing material also requires
the necessary rights from its copyright holders. For those reasons, adopting
MPL-2.0 should be treated as a separate relicensing project if the project's
commercial-integration goals later outweigh AGPL's network reciprocity.

This document records the project decision and is not legal advice. The
authoritative terms are in the repository's root `LICENSE` file. Useful primary
references are Mozilla's [MPL 2.0 FAQ](https://www.mozilla.org/MPL/2.0/FAQ/) and
the GNU Project's
[explanation of the Affero GPL](https://www.gnu.org/licenses/why-affero-gpl.html).
