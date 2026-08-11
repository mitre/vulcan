# Bootstrap Tier Wiring — Appendix (v2-g4n.4 agent evidence)

> Companion to `bootstrap-tier-wiring-design.md`. Verbatim evidence tables from the
> 2026-06-10 three-agent review. Line numbers: Bootstrap = `node_modules/bootstrap/scss/`
> at 4.6.2; Vulcan = `app/javascript/application.scss` pre-implementation.

## A. Bootstrap 4.6.2 variable inventory (bg / cap / border per component)

Line numbers from `_variables.scss`.

| Component | Background vars | Cap/header/state vars | Border/divider vars |
|---|---|---|---|
| Body/global | `$body-bg` (168) | — | `$border-color` (238), `$hr-border-color` (331) |
| Table | `$table-bg` (356, null), `$table-accent-bg` (357), `$table-hover-bg` (359), `$table-active-bg` (360), `$table-dark-bg` (370), `$table-dark-accent-bg` (371), `$table-dark-hover-bg` (373) | `$table-head-bg` (365) | `$table-border-color` (363), `$table-dark-border-color` (374) |
| Forms (input) | `$input-bg` (474), `$input-disabled-bg` (475), `$input-focus-bg` (486) | — | `$input-border-color` (478), `$input-focus-border-color` (487) |
| Input group | `$input-group-addon-bg` (520) | — | `$input-group-addon-border-color` (521) |
| Custom controls | `$custom-control-indicator-bg` (530), `-disabled-bg` (539), `-checked-bg` (543), `-checked-disabled-bg` (544), `-active-bg` (552), `$custom-checkbox-indicator-indeterminate-bg` (559) | — | `$custom-control-indicator-border-color` (534), `-checked-border-color` (546), `-focus-border-color` (549), `-active-border-color` (554), indeterminate (563) |
| Custom select | `$custom-select-bg` (582), `-disabled-bg` (583) | — | `$custom-select-border-color` (594), `-focus-border-color` (598) |
| Custom range | `$custom-range-track-bg` (615), `-thumb-bg` (621), `-thumb-active-bg` (627), `-thumb-disabled-bg` (628) | — | — |
| Custom file | `$custom-file-bg` (642), `-disabled-bg` (634), `-button-bg` (648) | — | `$custom-file-border-color` (644), `-focus-border-color` (632) |
| Nav tabs/pills | `$nav-tabs-link-active-bg` (706), `$nav-pills-link-active-bg` (711) | — | `$nav-tabs-border-color` (701), `-link-hover-border-color` (704), `-link-active-border-color` (707), `$nav-divider-color` (713) |
| Navbar | toggler-icon-bg ×2 (741, 748) — data-URI SVGs | — | toggler-border-color ×2 (742, 749) |
| Dropdown | `$dropdown-bg` (767), `-link-hover-bg` (778), `-link-active-bg` (781) | — | `$dropdown-border-color` (768), `$dropdown-divider-bg` (772) |
| Pagination | `$pagination-bg` (803), `-hover-bg` (811), `-active-bg` (815), `-disabled-bg` (819) | — | border-color companions (805, 812, 816, 820) |
| Jumbotron | `$jumbotron-bg` (830) | — | — |
| Card | `$card-bg` (845) | `$card-cap-bg` (841) | `$card-border-color` (839) |
| Tooltip | `$tooltip-bg` (862) + `$tooltip-arrow-color` alias | — | — |
| Popover | `$popover-bg` (885) + arrow alias | `$popover-header-bg` (893) | `$popover-border-color` (888), `$popover-arrow-outer-color` (906) |
| Toast | `$toast-background-color` (916) | `$toast-header-background-color` (923) | `$toast-border-color` (918), `$toast-header-border-color` (924) |
| Badge | none — variants via `badge-variant()` (color-yiq + darken, theme colors only) | — | — |
| Modal | `$modal-content-bg` (958), `$modal-backdrop-bg` (966) | — | `$modal-content-border-color` (959), `$modal-header-border-color` (968), `$modal-footer-border-color` (969) |
| Alert | none — `theme-color-level($color, $alert-bg-level)` (998) | — | same mechanism |
| Progress | `$progress-bg` (1007), `$progress-bar-bg` (1011) | — | — |
| List group | `$list-group-bg` (1019), `-hover-bg` (1027), `-active-bg` (1029), `-disabled-bg` (1033), `-action-active-bg` (1039) | — | `$list-group-border-color` (1020), `-active-border-color` (1030) |
| Thumbnail | `$thumbnail-bg` (1045) | — | `$thumbnail-border-color` (1047) |
| Breadcrumb | `$breadcrumb-bg` (1068) | — | `$breadcrumb-divider-color` (1069) |
| Close | none (`$close-color`, `$close-text-shadow` direct) | — | — |
| Misc | `$mark-bg` (343), `$kbd-bg` (1132), `$component-active-bg` (251) | — | — |

Badge/alert/close have **no** bg variables to wire — they derive entirely from theme colors
through the variant loops.

## B. var() injection safety map

Legend — **SAFE**: only direct CSS usage; can hold `var()`. **TRAPPED-HARD**: Sass color
function applied in a partial/mixin — must stay literal per mode. **TRAPPED-SOFT**: color
function only in another variable's `!default` — escape by also overriding the derived var.
**COND**: trapped only if `$enable-gradients: true` (pin it `false`).
`bs/` = bootstrap scss, `bv/` = bootstrap-vue src.

| Variable | Verdict | Trapping site / notes |
|---|---|---|
| `$body-bg` | SAFE (COND) | gradient `mix()` traps dead while gradients off |
| `$border-color`, `$hr-border-color` | SAFE | direct |
| `$table-bg`, `$table-accent-bg`, `$table-head-bg`, `$table-border-color` | SAFE | BV `if()`/`linear-gradient()` interpolations are var-safe |
| `$table-hover-bg` | SAFE\* | \*transitively trapped via `$table-active-bg: $table-hover-bg !default` (360) — MUST override `$table-active-bg` with a literal |
| `$table-active-bg` | **TRAPPED-HARD** | `bs/mixins/_table-row.scss:26` — `darken($background, 5%)` unconditional |
| `$table-dark-bg` | TRAPPED-SOFT | 374 `lighten()` → override `$table-dark-border-color` |
| `$input-bg` | SAFE | direct; propagates cleanly into focus/select/file/control-indicator aliases |
| `$input-disabled-bg` | SAFE | direct + 6 BV sites (form-rating:31, calendar:25, form-btn-label-control:106, spinbutton:70, time:9, form-tags:25) |
| `$input-border-color`, `$input-focus-bg`, `$input-focus-border-color` | SAFE | direct (defaults derive — overriding skips) |
| `$input-group-addon-bg/-border-color` | SAFE | direct |
| custom-control indicator bg/border/disabled | SAFE | direct |
| indicator checked/active, range thumbs, file button | SAFE (COND) | `gradient-bg()` only |
| `$custom-select-bg` | SAFE | var() valid as color component of background shorthand |
| custom select/file disabled + borders, range track | SAFE | direct |
| nav tabs/pills actives + borders, nav-divider | SAFE | direct; var() in border shorthand list valid |
| navbar toggler-icon-bg ×2 | **TRAPPED (interpolation)** | data-URI SVG embeds color — var() can't resolve in URL; per-theme literal URL |
| `$dropdown-bg/-border-color/-divider-bg` | SAFE | direct |
| `$dropdown-link-hover-bg/-active-bg` | SAFE (COND) | `gradient-bg()` |
| pagination all bg + borders | SAFE | direct |
| jumbotron, breadcrumb, progress, thumbnail, mark, kbd | SAFE | direct single usages |
| `$card-bg/-cap-bg/-border-color` | SAFE | direct (`bs/_card.scss:12,14,87,88,98,99`) |
| `$tooltip-bg` | SAFE | direct + arrow alias |
| `$popover-bg` | SAFE\* | \*default `$popover-header-bg: darken($popover-bg, 3%)` (893) — MUST override `$popover-header-bg` literal |
| `$popover-header-bg` | **TRAPPED-HARD** | `bs/_popover.scss:159` `darken($popover-header-bg, 5%)` |
| `$popover-border-color` | TRAPPED-SOFT | 906 `fade-in()` → override `$popover-arrow-outer-color` |
| `$toast-background-color` | **TRAPPED-HARD (BV)** | `bv/components/toast/_toast.scss:17,26` `rgba($var, opacity)` = SILENT runtime breakage; `bv/_variables.scss:131` `alpha()` = compile error |
| toast header bg + borders | SAFE | direct |
| modal content/backdrop bg + all 4 border colors | SAFE | direct (`bs/_modal.scss:115,117,132,146,179`) |
| list-group all bg + borders | SAFE | variant-loop `darken()` never touches these vars |
| `$component-active-bg` | TRAPPED-SOFT ×4 | rgba/lighten defaults at 395/487/552/627 — keep literal (theme primary, not a tier) |

**Dart Sass failure modes**: `darken(var(),%)` = loud compile error; `rgba(var(--x), .5)` =
silent invalid CSS at runtime (renders as no background, green CI).

**BootstrapVue additions**: toast trap above is the only BV hard trap on a wireable var.
Theme-color loops (tooltip/popover/form-input validation) trap `$primary`…`$dark` from holding
var() — theme colors stay literal. BV table sort icons are data-URI SVGs with hardcoded
fills — dark tables need the `-dark` icon set or post-import URL overrides.

**Precedent**: BS5.3 upstream uses exactly this pattern (`$modal-content-bg: var(--bs-body-bg)`),
eliminating color-function consumption to do it. BS4 community: johanlef gist; limitation
tracked in twbs/bootstrap#26596. Selective bg/border injection = proven safe subset.

## C. Vulcan override census (application.scss pre-implementation)

Classifications: CORRECT / INCORRECT (wrong tier or off-system token) /
REDUNDANT-ONCE-WIRED (deletable after variable wiring). Dark block = lines 162–836.

| Lines | Selector | Token(s) | Classification |
|---|---|---|---|
| 310–323 | btn-outline/badge variant loops | compiled mixes | CORRECT — not wireable, stays |
| 326–333 | `.card,.list-group-item,.modal-content,.popover,.dropdown-menu` (+!important ×2) | component-bg | INCORRECT token + REDUNDANT-ONCE-WIRED |
| 335–345 | card/modal/dropdown borders | border-color | REDUNDANT-ONCE-WIRED |
| 347–355 | `.dropdown-item` hover | component-bg-alt | INCORRECT + REDUNDANT-ONCE-WIRED |
| 357–363 | dropdown divider, list-group borders | border-color | REDUNDANT-ONCE-WIRED |
| 365–372 | popover header/body | component-bg-alt | INCORRECT + REDUNDANT-ONCE-WIRED |
| 374–393 | tooltip + arrows | inverted grays | CORRECT result, fragile indirection |
| 396–409 | `.bg-light/.bg-white/.btn-light` (!important required) | component-bg/-alt | mechanism stays; tokens INCORRECT |
| 412–423 | text/border utilities (!important required) | canonical ✓ | CORRECT |
| 428–450 | alert/toast variant loops | compiled mixes | CORRECT — stays |
| 454–473 | base toast surfaces (specificity-engineered) | secondary/tertiary ✓ | CORRECT — only block using canonical tiers properly |
| 476–478 | link `:not()` chain | link-color | CORRECT ($link-color trapped by darken) |
| 481–502 | `.form-control,.custom-select` (+!important ×9) | component-bg/-alt | **INCORRECT — the pinned bug** (orphaned input-bg ignored) + REDUNDANT-ONCE-WIRED |
| 504–508 | `.input-group-text` | component-bg-alt | INCORRECT + REDUNDANT-ONCE-WIRED |
| 510–533 | table head/cells/hover/stripe | tertiary ✓ / hover-bg / hardcoded stripe rgba | head CORRECT-tier; stripe INCORRECT; all REDUNDANT-ONCE-WIRED |
| 536–538 | `.b-table-sticky-header` | component-bg | INCORRECT |
| 541–556 | pagination | component-bg/-alt | INCORRECT + REDUNDANT-ONCE-WIRED |
| 559–575 | custom controls / file | component-bg/-alt | INCORRECT + REDUNDANT-ONCE-WIRED |
| 578–624 | vue-multiselect ×10 (+!important ×2) | component-bg/-alt | third-party, permanent; retoken to tiers |
| 627–657 | breadcrumb, nav-tabs | component-bg/-alt | INCORRECT + REDUNDANT-ONCE-WIRED |
| 659–661 | nav-pills active | primary ✓ | CORRECT |
| 666–678 | navbar-dark link alphas | hardcoded rgba | INCORRECT-by-inconsistency (dark only; rationale applies both modes) |
| 681–683 | bare `thead th` | component-bg-alt | **DEAD — loses to 518–523** |
| 688–703 | sidebar, close, jumbotron | component-bg/-alt | sidebar/jumbotron INCORRECT; close CORRECT |
| 706–708 | `hr` | border-color | REDUNDANT (duplicates 1019–1021 with different token) |
| 712–768 | EasyMDE/CodeMirror ×9 (+!important ×14) | component-bg/-alt | third-party, permanent; retoken |
| 775–830 | triage data-attr tokens | status mixes | CORRECT (app layer) |
| 833–835 | `.text-muted` (!important required) | text-muted | CORRECT |
| 1000–1021 | code/kbd/pre/mark/hr globals | canonical ✓ | CORRECT pattern; light wireable |
| — | `.modal-header/.modal-footer` | — | **GAP — zero rules anywhere** |
| — | light-mode component tiering | — | **GAP — nothing outside dark block** |

**Metrics**: 36 `!important` in application.scss (35 in dark block: ~10 required vs BS
utilities, ~14 vs EasyMDE, ~11 defensive over-armoring) + 16 triage-tints + 1 shiki = 53
layer-wide. 103 tokens defined / 27 orphans (entire input set ×2 definitions + validation set,
tertiary-color, heading-color, link-hover-color, border-color-translucent, shadows, …) /
2 phantoms (`--vulcan-action-btn-font-size`, `--vulcan-section-label-font-size`).
BV CSS double-ship: `application.scss:2` (src→317KB) + `bootstrap-vue.scss` (dist 87KB,
loads LAST — `application.html.haml:10-11`).

## D. Token gap + drift summary (vs canonical BS5.3)

**Missing**: `-rgb` channel tokens (body-bg/body-color/emphasis/{theme}); theme triads
(`-text-emphasis/-bg-subtle/-border-subtle`, both modes); focus-ring family; box-shadow-inset;
link-decoration; the entire Layer-1.5 component token layer; dark asset tokens (SVGs).

**Value bugs**: light tiers swapped (secondary↔tertiary); emphasis-color light = body-color;
dark mark-bg mix weights backwards (should be ≈`#664d03`); two disagreeing disabled tokens;
theme colors mutate in dark (BS keeps invariant); gray scale inverts in dark (BS keeps
constant); dark border-color `#6c757d` vs BS `#495057` (kept per D5, documented).

**Drift/aliases to retire**: `component-bg`(→body-bg per D1), `component-bg-alt`(→tertiary or
secondary per use), `text`, `bg-light`, `border-light/border-subtle/divider`
(→border-color-translucent), `text-muted`(→secondary-color), `hover-bg(-light)`(→tertiary-bg),
`active-bg/active-tint(-hover)/focus-tint`(→primary-bg-subtle family), `primary-dark`
(→link-hover-color), `input-focus-border`(→focus-ring-color), `disabled-bg`(→secondary-bg),
`highlight-*` diff tokens (→`--vulcan-diff-*`, BS vocab collision).

**Blast radius (component-bg/-alt outside application.scss)**: MarkdownTextarea.vue (8, incl.
a JS string at 241 + inline style at 8), FilterGroup.vue (66, 75), BenchmarkTable.vue (270),
BulkTriageBar.vue (134), CommentProgressBar.vue (216), triage-tints.css (74–124 — pill-fg use
is semantically on-color, replace with body-bg/dedicated token, NOT a surface tier),
shiki-preview.css (6). Hardcoded hex fallbacks in those files die in the same pass (.5d).
