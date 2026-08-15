# SRG Authoring Workflow

How to author a Security Requirements Guide (SRG) in Vulcan — from choosing the SRG profile at creation, through the requirement lifecycle and public comment, to releasing the SRG into the catalog where it seeds STIG components.

## The SRG Document Hierarchy

DISA security guidance is built in three layers:

1. **Core SRGs** — the three top-level requirement catalogs: SRG-NET (network), SRG-OS (operating system), and SRG-APP (application). These are non-public working documents maintained by the SRG author community and uploaded to Vulcan by the authors who hold them.
2. **Derived SRGs** — technology-scoped SRGs authored from the cores and published on DISA Cyber Exchange. The General Purpose OS SRG (GPOS) is derived from the OS core; the Container Platform SRG is derived from the APP core. A derived requirement's identifier carries both namespaces: `SRG-APP-000014-CTR-000035` is the APP core requirement `SRG-APP-000014` as tailored for the Container Platform SRG (`CTR`).
3. **STIGs** — product-specific implementation guides based on derived SRGs. This is the vendor STIG workflow described in the rest of this guide.

Vulcan supports authoring the middle layer: an **SRG Component** derives a new SRG (or its next release) from one or more core SRGs. Once released, the SRG joins Vulcan's catalog, where STIG Components can base on it.

## Choosing What You Are Authoring

Creating a component begins with one choice — **STIG** or **SRG**:

- **STIG** — implement an existing SRG's requirements for a specific product. Each requirement is worked to a compliance posture: Configurable, Inherently Meets, Does Not Meet, or Not Applicable.
- **SRG** — author a new Security Requirements Guide derived from core SRGs. Each requirement is a decision about whether it applies to the technology, with tailored content.

The choice is **permanent for the component** — the two profiles use different status vocabularies and different requirement records, so there is no in-place conversion. If you pick the wrong profile, delete the component and recreate it (export a backup archive first to carry your content across; the archive restores through the import flow).

What the choice changes:

| Surface | STIG component | SRG component |
|---|---|---|
| Base documents | one or more derived SRGs from the catalog | one or more **core** SRGs |
| Requirement statuses | Not Yet Determined, Applicable – Configurable, Applicable – Inherently Meets, Applicable – Does Not Meet, Not Applicable | Not Yet Determined, Applicable, Not Applicable |
| Satisfied-By | available | not part of SRG authoring |
| Relocation | — | propose moving a requirement to another SRG |
| Published document | STIG XCCDF (and InSpec) | SRG XCCDF |

The base-document pickers are mirror images: a core SRG is never a valid STIG base, and a derived SRG is never a valid SRG base. The picker only shows valid choices for the profile you selected.

### Creating an SRG Component

1. Choose **SRG** as the document type.
2. Select one or more **core SRGs** as source documents. Most SRGs derive from a single core (the Container Platform SRG derives from the APP core alone); a second core can be added later for selected requirements, so dual lineage is supported without being the default.
3. Enter the component prefix. Its leading letters (for example `CTR`, `GPOS`, `DB`) serve as the SRG's **abbreviation** — the second half of every released requirement identifier.
4. Choose the import mode: every requirement from every selected core (the default), or a selective pick.

The component is created with its requirements imported in **Not Yet Determined** status. Requirements can also be added directly at any time — an SRG is not limited to what it imports from the cores. A directly added requirement has no core lineage and receives an abbreviation-only identifier at release.

## The Requirement Lifecycle

An SRG requirement has three statuses: **Not Yet Determined**, **Applicable**, and **Not Applicable**.

| | Not Yet Determined | Applicable | Not Applicable |
|---|---|---|---|
| Title, Vulnerability Discussion, Check, Fix | editable | editable | hidden (content is retained) |
| Status Justification | — | — | shown and **required** |
| Severity, CCI / IA Controls | inherited from the core, read-only | inherited from the core, read-only | hidden |
| At release | blocks release | included in the SRG | excluded from the SRG |

- Requirements start **Not Yet Determined** and are fully editable — tailor content and decide applicability in either order; the status records the decision, it does not gate the work.
- **Applicable** — the requirement applies to this technology and will be included in the released SRG.
- **Not Applicable** — the requirement does not apply to this technology. A justification is required and the requirement is excluded from the released SRG. The requirement and its justification stay on the component as the working record of the decision.

Severity and CCI / IA control values are inherited from the core requirement and shown read-only; overriding them is a publisher-level action.

### Moving a Requirement to Another SRG

Sometimes a requirement belongs in a different SRG rather than being Not Applicable. An author **proposes a relocation** naming the destination SRG; an author on the receiving SRG's component reviews the proposal and either **concurs** or **non-concurs** (with rationale). On concurrence the requirement lands in the destination component and leaves this document — the removal is recorded in the release changelog.

## Review, Public Comment, and Locking

SRG components use the same collaboration workflow as STIG components: authoring, review requests, approvals, comments, and **locking** work identically. Every requirement must be locked before the SRG can be released.

A draft SRG takes public comment exactly like a draft STIG. The component's comment period moves through three phases:

1. **Open** — accepting new comments; adjudication can begin while the period is open.
2. **Closed, adjudicating** — no new comments; existing comments are still being triaged and dispositioned.
3. **Closed, finalized** — the comment record is frozen.

## Releasing the SRG

Release is available once:

- every live requirement is **decided** — none left Not Yet Determined,
- every requirement is **locked**,
- the component's **version and release** numbers are set, and
- the component has an **abbreviation** to build identifiers with.

Releasing performs one atomic operation — if any step fails, nothing is published:

1. **Final identifiers are minted.** While authoring, requirements display their core lineage. At release each Applicable requirement receives its permanent identifier: the core requirement identifier, the SRG's abbreviation, and a six-digit sequence — for example `SRG-APP-000014-CTR-000035`. Directly added requirements without core lineage mint abbreviation-and-sequence identifiers (for example `CTR-000036`). A published identifier is never renumbered: later releases carry it forward unchanged, and a retired sequence number is never reused.
2. **The SRG XCCDF is generated.** Only Applicable requirements publish. Not Applicable requirements are excluded from the document; their justifications remain on the component.
3. **The catalog entry is created.** The released SRG appears in Vulcan's SRG catalog shaped exactly like an SRG uploaded from XML.
4. **The release changelog is built**, listing requirements that were relocated out of the document.

## From Published SRG to STIGs

The released catalog entry works like any uploaded SRG:

- **STIG Components can base on it immediately** — the published SRG seeds STIG authoring with its Applicable requirements, completing the hierarchy: core SRG → derived SRG → STIG.
- **Version currency applies.** When a newer release of a base SRG exists, components based on the older release are flagged as out of date — the same staleness signal at every level. A core update flows to the derived SRGs authored from it, and a derived SRG update flows to the STIGs based on it.
- **The next release of the SRG** starts from a copy of the released component, reconciled against the latest core releases: unchanged requirements re-link and refresh their inherited fields, requirements that vanished from the core are kept with their existing decisions and reported, and newly arrived core requirements are imported as Not Yet Determined. Minted identifiers carry forward unchanged; only new requirements mint new sequence numbers.
