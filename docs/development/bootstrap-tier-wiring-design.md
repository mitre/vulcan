# Bootstrap Tier Wiring — Design (v2-g4n.4)

> Status: **APPROVED** — Aaron, 2026-06-10: "approved on all 6 with your recommendations"
> (D1 keep elevation in component tokens, D2 fix swapped light tiers, D3 translucent-ink
> modal header/footer, D4 fill-distinct via D1, D5 keep border deviation, D6 translucent ink)
> plus the .5a–.5d implementation split.
> Sources: 3-agent expert review, 2026-06-10 — BS4.6.2 theming architecture, BS5.3 reference
> architecture + gap analysis, full Vulcan override audit. Findings logged on card v2-g4n.4.
> Full variable inventory, var() safety map, and override census: see companion
> `bootstrap-tier-wiring-appendix.md`.

## 1. The error, stated plainly

Bootstrap 4 was compiled untouched: line 1 of `application.scss` imports stock Bootstrap with
zero variable wiring, so every component variable (`$card-bg`, `$input-bg`, `$modal-content-bg`,
`$table-head-bg`, …) froze to its light-mode default. The design system was then bolted on
*after* compilation as a parallel CSS-custom-property vocabulary plus ~70 selector-override
blocks and 35 dark-block `!important`s that re-paint, surface by surface, what the Sass variable
layer would have expressed in one place. Because the overrides were written ad hoc rather than
derived from the tiers, the vocabulary drifted:

- A "backwards-compat" alias (`--vulcan-component-bg` / `-alt`) became the de facto surface
  token while the canonical tiers go mostly unused
- The purpose-built input and form-validation token sets are **defined twice and consumed zero
  times** while `.form-control` paints the wrong tier from the alias
- `thead th` is painted two different colors by two rules (one is dead)
- Modal header/footer were missed entirely (stock light hairlines on dark modals)
- **Light mode got no tiering at all** — the tier system exists only as a dark-mode paint job

Two compounding latent bugs:

- **Light tiers are SWAPPED vs the BS5.3 system we ported**: Vulcan light has
  `secondary-bg: $gray-100`, `tertiary-bg: $gray-200`; canonical is the reverse. Dark values
  match canon — so the tier ramp inverts between modes and every consumer gets the wrong tier
  in exactly one mode.
- **BootstrapVue CSS ships twice**: `application.scss:2` compiles `bootstrap-vue/src` into
  `application.css` (317KB) AND the esbuild entry `bootstrap-vue.scss` imports the upstream
  **prebuilt stock dist CSS** (87KB), loaded *last* in the layout
  (`application.html.haml:10-11`). Identical today, but it would silently re-stock every
  wired BootstrapVue style the moment variables are customized. **Removing it is step zero.**

## 2. Reference architecture (Bootstrap 5.3, verified from source)

- **Tier semantics** (official): components sit on **`body-bg`** and are border-delimited.
  `tertiary-bg` = hover states, accents, wells (1 step from body). `secondary-bg` = disabled
  states, dividers, tracks (2 steps from body). The ramp direction is identical in both modes.
- **Dark mode flips ~30 root tokens only** — component tokens cascade because their values are
  `var()` references. No per-component dark overrides except non-cascadable assets (SVGs).
- **Translucent ink, not opaque tint, for caps/striping**:
  `card-cap-bg = rgba(body-color-rgb, .03)`, table striped/hover =
  `rgba(emphasis-color-rgb, .05/.075)` — self-adapting in both modes, requires `-rgb`
  channel tokens.
- **Modal headers/footers are NOT tinted in Bootstrap — by design** (no such variable exists in
  BS4 or BS5.3). The one tinted header in the framework: `popover-header-bg = secondary-bg`.
  Card caps ARE tinted (translucent ink). Tinting modal header/footer is therefore a
  *documented Vulcan extension*, not a wiring of something Bootstrap provides.
- **Inputs are body-bg, border-delimited, in both modes.** Readability comes from
  `input-border-color = border-color` + placeholder = `secondary-color`, disabled steps up to
  `secondary-bg`. A fill-distinct input is a *documented Vulcan extension* (decision below).

## 3. The mechanism (Bootstrap 4's designed customization path)

```scss
@import "bootstrap/scss/functions";   // required first
// === Vulcan variable wiring (the layer that never existed) ===
$body-bg: …;  $input-bg: var(--vulcan-input-bg);  $card-cap-bg: …;  // etc per map
$enable-gradients: false;             // pin explicitly — gradients resurrect mix() traps
@import "bootstrap/scss/bootstrap";   // everything after sees our values
```

Every BS4 variable is `!default` — assignments before the import win. We inject **CSS custom
property references into the SAFE subset** of variables so components consume runtime tiers in
both modes (this is BS5.3's own architecture, retrofitted at the BS4 compile step; precedent:
twbs/bootstrap#26596, johanlef gist — selective injection of bg/border vars is the proven safe
subset; theme colors stay literal).

### var() safety verdicts (full map in agent report, card v2-g4n.4)

- **SAFE (the overwhelming majority)**: body/table(bg,head,accent,hover,border)/input(all
  incl. focus, disabled, addon)/custom controls/select/file/range/nav/dropdown/pagination/
  jumbotron/breadcrumb/progress/card(bg,cap,border)/tooltip/popover-bg/toast(header,borders)/
  modal(all)/list-group(all)/thumbnail/mark/kbd + their border companions.
- **TRAPPED-HARD (3 + icons — stay per-mode literals, handled by a small retained dark block)**:
  - `$table-active-bg` (`mixins/_table-row.scss:26` `darken()`)
  - `$popover-header-bg` (`_popover.scss:159` `darken()`)
  - `$toast-background-color` (BootstrapVue `rgba($var, opacity)` — **silent** runtime
    breakage, not a compile error)
  - Data-URI SVGs (navbar togglers, BV table sort icons) — `var()` can't reach inside URLs
- **TRAPPED-SOFT (escape by also overriding the derived var)**: `$table-hover-bg` (frees via
  literal `$table-active-bg`), `$popover-bg` (frees via literal `$popover-header-bg`),
  `$popover-border-color` (via `$popover-arrow-outer-color`), `$table-dark-bg`,
  `$component-active-bg` (keep literal — it's theme primary, not a tier).
- **Not wireable at all (variant loops)**: alerts, badges, button variants — BS4 derives them
  through `color-yiq()`/`theme-color-level()`. The existing dark-block variant `@each` loops
  stay (they are already classified CORRECT in the audit).

**Dart Sass failure modes**: `darken(var(),%)` = loud compile error; `rgba(var(--x), .5)` =
silent invalid CSS at runtime. Every injection must be checked against the safety map AND
visually verified per component.

## 4. Canonical target vocabulary (Layer 1 / 1.5 / 2)

**Layer 1 — root tokens, 1:1 with BS5.3 semantics** (full set in agent report):

| Token | Light | Dark | Note |
|---|---|---|---|
| `--vulcan-body-bg` (+`-rgb`) | `#fff` | `#212529` | unchanged |
| `--vulcan-secondary-bg` | **`#e9ecef`** | `#343a40` | **FIX: light value swapped today** |
| `--vulcan-tertiary-bg` | **`#f8f9fa`** | `#2b3035` | **FIX: light value swapped today** |
| `--vulcan-body-color` (+`-rgb`) | `#212529` | `#dee2e6` | unchanged |
| `--vulcan-emphasis-color` (+`-rgb`) | **`#000`** | `#fff` | FIX: light = body-color today (zero gain) |
| `--vulcan-secondary-color` / `tertiary-color` | rgba(body-color, .75/.5) | same formula | tertiary-color is currently an orphan |
| `--vulcan-border-color` | `#dee2e6` | `#495057` *or keep `#6c757d`* | decision D5 |
| `--vulcan-border-color-translucent` | rgba(0,0,0,.175) | rgba(255,255,255,.15) | absorbs border-light/border-subtle/divider |
| `--vulcan-{theme}` + `-rgb` | mode-invariant | mode-invariant | **stop mutating in dark** |
| `--vulcan-{theme}-text-emphasis/-bg-subtle/-border-subtle` | per BS formulas | per BS formulas | replaces `-tint` triads; new in light |
| `--vulcan-gray-100..900` | constants | constants | **stop inverting in dark** |
| focus-ring family, form-valid/invalid, highlight (mark) | per BS | per BS | mark-bg dark fix: `#664d03` not the current backwards mix |

**Layer 1.5 — component tokens defaulting to root via `var()` (the missing layer; what the Sass
variables get wired to):** `--vulcan-modal-bg`, `--vulcan-card-bg`, `--vulcan-card-cap-bg`,
`--vulcan-input-bg`, `--vulcan-input-disabled-bg`, `--vulcan-dropdown-bg`,
`--vulcan-dropdown-link-hover-bg`, `--vulcan-popover-bg/-header-bg`, `--vulcan-table-*`,
`--vulcan-list-group-*`, `--vulcan-pagination-*`, etc. Surface look is encoded HERE (see D1),
so root tiers keep canonical semantics regardless of the elevation decision.

**Layer 2 — app-domain (keep, rename collisions)**: diff/status tokens (`highlight-*` renamed
`--vulcan-diff-*` — collides with BS mark vocabulary), shadows, overlays, focus-ring-warning.

**Retire as aliases during migration** (full mapping in agent report): `component-bg` →
body-bg (or per-D1), `component-bg-alt` → tertiary/secondary per use, `bg-light`, `text`,
`text-muted`, `hover-bg(-light)`, `disabled-bg`, `active-*`/`focus-tint` family,
`border-light/border-subtle/divider`, `primary-dark`, `input-focus-border`.

## 5. Tier map — APPROVAL TABLE (decisions D1–D6)

| # | Decision | Options | Recommendation |
|---|---|---|---|
| **D1** | Dark surface model: components on body-bg (BS canon, border-delimited) vs current Material-style elevation (surfaces = gray-800, one step above page) | canon / keep elevation | **Keep the elevated look** (it's the app's current dark identity) but encode it ONLY in Layer-1.5 component tokens (`--vulcan-card-bg: var(--vulcan-secondary-bg)` in dark) so root tiers stay canonical |
| **D2** | Fix the swapped light tiers (secondary ↔ tertiary) | fix / keep | **Fix.** Visible light-mode changes are small (tints one step subtler/stronger); every future consumer stops being wrong in one mode. Implementation screenshots will show the diff |
| **D3** | Modal header/footer treatment (your ask; a Vulcan extension — BS never tints them) | translucent ink like card-cap: `rgba(body-color-rgb, .03)` / solid tier (`tertiary-bg`) / borders only (BS canon) | **Translucent ink** — matches card-cap, self-adapts both modes, zero per-mode rules |
| **D4** | Form-field background (your ask; BS canon = body-bg + borders) | keep canon / fill-distinct via solid tier | **Fill-distinct**: inputs = `body-bg` while surfaces they sit on are tiered per D1 — on elevated dark surfaces inputs naturally read as wells. If light mode still reads flat after D1/D2, step inputs to a dedicated `--vulcan-input-bg` literal pair. Verify visually at implementation |
| **D5** | Dark border-color: revert to BS `#495057` or keep deliberate lighter `#6c757d` | revert / keep | **Keep `#6c757d`** as a documented a11y deviation (it was deliberate); revisit after D1/D2 land |
| **D6** | Caps/striping/hover translucency: opaque tier vars vs translucent ink | per-variable | **Translucent ink** wherever BS uses it (card-cap, table stripe/hover, hr) — requires the new `-rgb` tokens; opaque tiers for true surfaces (dropdown-hover, disabled, tracks) |

## 6. Override demolition plan (from the audit census)

After wiring, the dark block shrinks to exactly:

1. Variant `@each` loops (alerts, badges, outline buttons, toasts) — not wireable, already correct
2. BS-`!important` utility counters (`.bg-light`, `.btn-light`, `.text-*`, `.border`) — required
3. The 3 TRAPPED-HARD literals + data-URI icon swaps
4. Third-party: vue-multiselect (10 blocks) + EasyMDE/CodeMirror (9 blocks) — retokened to
   canonical tiers but permanent
5. App-domain blocks (triage tokens, sidebar)

Everything else (~half the dark block) is REDUNDANT-ONCE-WIRED and gets deleted: the fad.2
component block, form-control/custom-control/file/select blocks, table head/stripe/hover,
pagination, breadcrumb, nav-tabs, popover, dropdown, jumbotron, dead `thead th`, duplicate `hr`.
Light mode gets tiering through the same wiring with zero added rules.

## 7. Migration map (proposed implementation children — replaces single-card v2-g4n.5)

| Child | Scope | Est |
|---|---|---|
| .5a **Step zero** | Remove BV dist double-ship (`bootstrap-vue.scss` entry, esbuild entry list, layout line); verify BV styles intact from source compile | sp:2 |
| .5b **Token layer rewrite** | Layer 1 root tokens per §4 (tier swap fix, -rgb channels, theme triads, mode-invariant palette, emphasis/mark fixes) + Layer 1.5 component tokens + alias shims for retired names | sp:5 |
| .5c **Pre-import wiring + demolition** | functions→overrides→bootstrap restructure; inject SAFE vars per map; literal handling for trapped 3; delete REDUNDANT-ONCE-WIRED census rows; per-component visual sweep both modes | sp:5 |
| .5d **Consumer retokening** | Blast radius: 10+ Vue files off `component-bg/-alt` (incl. MarkdownTextarea JS string + triage pill-fg semantic fix → body-bg/on-color); kill hardcoded hex fallbacks; delete alias shims | sp:3 |

Sequencing unchanged: behind v2-0re.10; k8f.2 (ConfirmModal) follows .5c.

## 8. Verification contract

Per child: `yarn build` clean (zero new warnings), full unit suite, zero stderr, Playwright
visual sweep light+dark of project page / component editor / a form modal / users admin / login,
screenshots READ. The silent-rgba() failure mode makes the visual sweep non-negotiable.
