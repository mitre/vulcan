# Vulcan Design System

Vulcan uses a layered CSS custom property architecture ported from Bootstrap 5.3's dark mode system onto Bootstrap 4.6.2. This system provides dark mode, consistent spacing, panel layouts, and triage status coloring across all Vue components.

## Quick Rules

1. **Use `--vulcan-*` variables** — never raw hex, rgba, or Bootstrap vars (`--primary`, `--info`)
2. **Use PanelLayout** for multi-column layouts — never ad-hoc `b-row`/`b-col` for panels
3. **Use BvConfig defaults** — don't set props that the global config already handles
4. **Use `.form-row`** for multi-column forms — never `.row` (15px gutters misalign form fields)
5. **You find it you fix it** — design system violations found during any card get fixed immediately

## Three-Tier Background Hierarchy

Ported from Bootstrap 5.3. Three background levels create visual depth:

| Tier | Variable | Light | Dark | Use for |
|------|----------|-------|------|---------|
| Body | `--vulcan-body-bg` | `#fff` | `#212529` | Page background, main content areas |
| Secondary | `--vulcan-secondary-bg` | `#f8f9fa` | `#343a40` | Elevated surfaces: sidebars, card headers |
| Tertiary | `--vulcan-tertiary-bg` | `#e9ecef` | `#2b3035` | Inset/recessed areas: form panels, table headers |

Matching text tiers:

| Tier | Variable | Light | Dark |
|------|----------|-------|------|
| Body | `--vulcan-body-color` | `#212529` | `#dee2e6` |
| Secondary | `--vulcan-secondary-color` | `rgba(#212529, 0.75)` | `rgba(#dee2e6, 0.75)` |
| Tertiary | `--vulcan-tertiary-color` | `rgba(#212529, 0.5)` | `rgba(#dee2e6, 0.5)` |
| Emphasis | `--vulcan-emphasis-color` | `#212529` | `#fff` |
| Muted | `--vulcan-text-muted` | `#6c757d` | `#adb5bd` |

## PanelLayout Component

Shared layout component for multi-panel pages. Encodes three lessons learned:

1. **`no-gutters`** — Bootstrap row gutters (15px) conflict with panel padding. PanelLayout uses `no-gutters` so panels own ALL their spacing.
2. **Layout owns the background** — Child components must NOT set `background-color`. PanelLayout's `bgTier` prop sets the correct tier per panel. Dark mode overrides on child components paint over the tier system.
3. **Layout owns the padding** — `p-3` (1rem) on the panel body guarantees consistent spacing. Don't add padding wrappers in slot content.

### Usage

```vue
<PanelLayout :panels="panels">
  <template #left>
    <!-- Sidebar content — no padding wrapper needed -->
    <nav>...</nav>
  </template>
  <template #center>
    <!-- Main content -->
    <div>...</div>
  </template>
  <template #right>
    <!-- Form/action panel -->
    <form>...</form>
  </template>
</PanelLayout>
```

### Props

```js
panels: [
  { name: 'left',   cols: 2, bgTier: 'secondary' },  // sidebar
  { name: 'center', cols: 5, bgTier: 'body' },        // main content
  { name: 'right',  cols: 5, bgTier: 'tertiary' },    // action panel
]
```

- `name` — slot name prefix (generates `left`, `left-header`, `left-footer`)
- `cols` — Bootstrap column width (1-12, used as `col-lg-{N}`)
- `bgTier` — one of `body`, `secondary`, `tertiary`

### Slots per panel

- `{name}` — main body content (rendered inside scrollable `p-3` container)
- `{name}-header` — fixed header with `px-3 py-2 border-bottom` (only renders if slot provided)
- `{name}-footer` — fixed footer with `px-3 py-2 border-top` (only renders if slot provided)

### Behavior

- Borders auto-placed between adjacent panels (1px solid `--vulcan-border-color`)
- Panel bodies have `overflow-auto` + `min-height-0` for scrollable content
- Mobile: all panels stack to `col-12`
- 2-panel mode: omit the right panel slots

### Consumers

- `TriageSplitView` — 3-panel triage workspace (sidebar + rule content + triage form)
- `ControlsPageLayout` — 2-panel rule editor (sidebar + main content)

### What NOT to do

```vue
<!-- WRONG: ad-hoc layout with grid gutter conflict -->
<b-row>
  <b-col md="3" class="sidebar pr-0 border-right">...</b-col>
  <b-col md="9">...</b-col>
</b-row>

<!-- WRONG: component overrides layout background -->
<style scoped>
.my-component { background-color: var(--vulcan-component-bg); }
</style>

<!-- WRONG: slot content adds its own padding -->
<template #left>
  <div class="p-3">...</div>  <!-- PanelLayout body already has p-3 -->
</template>
```

## Interaction State Variables

| Variable | Light | Dark | Use for |
|----------|-------|------|---------|
| `--vulcan-hover-bg` | `rgba(gray-600, 0.08)` | `rgba(gray-400, 0.12)` | List item hover |
| `--vulcan-hover-bg-light` | `rgba(gray-600, 0.04)` | `rgba(gray-400, 0.06)` | Section header hover |
| `--vulcan-active-bg` | `rgba(primary, 0.10)` | `rgba(primary-dark, 0.20)` | Selected sidebar item bg |
| `--vulcan-active-border` | `$primary` | `$primary-dark` | Selected item left border |
| `--vulcan-active-tint` | `rgba(primary, 0.10)` | `rgba(primary-dark, 0.12)` | Active group tint |
| `--vulcan-focus-tint` | `rgba(primary, 0.04)` | `rgba(primary-dark, 0.08)` | Focused section bg |

### Selected sidebar item pattern

```css
.selected-item {
  background: var(--vulcan-active-bg);
  border-left: 3px solid var(--vulcan-active-border);
}

.item:hover {
  background: var(--vulcan-hover-bg);
}
```

## Border Variables

| Variable | Light | Dark | Use for |
|----------|-------|------|---------|
| `--vulcan-border-color` | `#dee2e6` | `#6c757d` | Primary dividers, panel borders |
| `--vulcan-border-subtle` | `#e9ecef` | `#495057` | Faint dividers, table lines |
| `--vulcan-border-color-translucent` | `rgba(0,0,0,0.175)` | `rgba(255,255,255,0.15)` | Card/modal borders |
| `--vulcan-divider` | `#e9ecef` | `#495057` | Semantic alias for subtle borders |

## Form Control Variables

Ported from Bootstrap 5.3 — form controls reference global vars so they auto-adapt in dark mode:

| Variable | Resolves to |
|----------|-------------|
| `--vulcan-input-bg` | `var(--vulcan-body-bg)` |
| `--vulcan-input-color` | `var(--vulcan-body-color)` |
| `--vulcan-input-border-color` | `var(--vulcan-border-color)` |
| `--vulcan-input-placeholder-color` | `var(--vulcan-secondary-color)` |
| `--vulcan-input-disabled-bg` | `var(--vulcan-secondary-bg)` |

## Typography & Native Element Variables

Ported from Bootstrap 5.3 — these override Bootstrap 4's hardcoded colors on native HTML elements so they adapt to dark mode:

| Variable | Light | Dark | Element |
|----------|-------|------|---------|
| `--vulcan-code-color` | `$pink` | `mix(white, $pink, 40%)` | `<code>` inline text |
| `--vulcan-kbd-bg` | `$gray-900` | `$gray-700` | `<kbd>` background |
| `--vulcan-kbd-color` | `$white` | `$gray-100` | `<kbd>` text |
| `--vulcan-pre-color` | `$gray-900` | `$gray-300` | `<pre>` block text |
| `--vulcan-mark-bg` | `#fcf8e3` | `mix($gray-800, $yellow, 20%)` | `<mark>` highlight |
| `--vulcan-mark-color` | `$body-color` | `$gray-300` | `<mark>` text |
| `--vulcan-heading-color` | `inherit` | `inherit` | Heading text override |
| `--vulcan-hr-color` | `rgba(black, 0.1)` | `rgba(white, 0.15)` | `<hr>` border |

## Form Validation Variables

Ported from Bootstrap 5.3 — validation feedback colors adapt to dark mode:

| Variable | Light | Dark |
|----------|-------|------|
| `--vulcan-form-valid-color` | `$success` | `mix(white, $success, 40%)` |
| `--vulcan-form-valid-border-color` | `$success` | `mix(white, $success, 40%)` |
| `--vulcan-form-invalid-color` | `$danger` | `mix(white, $danger, 40%)` |
| `--vulcan-form-invalid-border-color` | `$danger` | `mix(white, $danger, 40%)` |

## BvConfig Global Defaults

`app/javascript/config/bootstrapVueConfig.js` sets component defaults for all 22 pack files:

```js
export const bvConfig = {
  BButton: { size: 'sm' },
  BFormInput: { size: 'sm' },
  BFormSelect: { size: 'sm' },
  BFormTextarea: { size: 'sm' },
  BDropdown: { size: 'sm' },
  BInputGroup: { size: 'sm' },
  BPagination: { size: 'sm' },
  BTable: { striped: true },
};
```

**Do NOT set these props per-instance** — they're handled globally. Adding `striped` to a `<b-table>` is redundant.

## Spacing Rules

- **Multi-column forms:** use `.form-row` (5px gutters), NOT `.row` (15px gutters)
- **Form group margin:** `.form-group` owns `margin-bottom: 1rem`. Do NOT override with custom classes.
- **`.rule-form-field`** controls padding + border-radius for rule editor fields. It does NOT set margin — `.form-group` handles that.
- **Horizontal label:value:** use `<b-form-group label-cols-md="3" label-align-md="right">` — NOT manual `.row > .col-4 > strong`

## Native HTML Elements

### `<details>` / `<summary>` (Disclosure Widget)

Styled globally with `--vulcan-*` variables. Used for collapsible content blocks — VitePress `::: details` syntax, in-app rendered via `DisaGuideController#convert_callouts`, or anywhere native disclosure is appropriate.

| Part | Variable | Purpose |
|------|----------|---------|
| Summary background | `--vulcan-tertiary-bg` | Visually recessed header |
| Summary text | `--vulcan-emphasis-color` | High contrast label |
| Border | `--vulcan-border-color` | Consistent with card borders |
| Open divider | `--vulcan-border-subtle` | Faint line between summary and body |
| Hover | `--vulcan-hover-bg` | Interactive feedback |

Auto-adapts to dark mode — no per-component overrides needed.

```html
<details>
  <summary>Click to expand</summary>
  <p>Content here uses body text color on body background.</p>
</details>
```

## Bootstrap-Vue Components to Use

| Component | Use for | Instead of |
|-----------|---------|------------|
| `b-media` | Comment/reply layouts | Ad-hoc divs with author + content |
| `b-avatar` | User initials in comments | Plain text author names |
| `b-skeleton` | Content loading placeholders | `b-spinner` for table/list loading |
| `b-alert` | Warning/info banners | Hand-built divs with bg-warning |
| `b-form-datepicker` | Date selection | `b-form-input type="date"` |
| `b-progress` | Progress bars | Custom div-based tracks |
| `b-collapse` | Show/hide animations | Hard `v-if` mount/unmount |

## Color Architecture (4 Layers)

```
Layer 1: --vulcan-*         Bootstrap Sass → CSS custom properties (application.scss)
Layer 2: --triage-*         Semantic mapping: triage status → core color (triage-tints.css)
Layer 3: [data-triage]      Data-attribute selectors → intermediate vars (triage-tints.css)
Layer 4: .component-class   ONE CSS rule reads intermediate vars (per-component)
```

Each layer references only the layer above. Adding a new triage status is a single edit to Layer 3.

### Dark Mode

`[data-bs-theme="dark"]` in `application.scss` overrides all `--vulcan-*` variables. Components using `var(--vulcan-*)` auto-adapt. The toggle is in `app/javascript/utils/colorMode.js`:

```js
import { initTheme, toggleTheme } from '../utils/colorMode';
initTheme();       // On page load — apply stored/preferred theme
toggleTheme();     // On button click — swap and persist
```

### Dark mode tint opacities

Light mode tints use 0.08-0.15 opacity. Dark mode increases to 0.18-0.22 for visibility on dark backgrounds. Extended palette (purple, teal, indigo) has explicit dark mode tints for withdrawn/duplicate/addressed-by triage statuses.

## TDD Guard Tests

`spec/config/design_system_audit_spec.rb` enforces the design system automatically:

| Test | What it catches |
|------|----------------|
| No hardcoded colors in Vue scoped styles | Hex/rgba not wrapped in `var()` |
| No arbitrary px > 4 for spacing | Pixel values that should be rem or Bootstrap utilities |
| CSS variable completeness | Variables referenced but undefined in `:root` |
| No margin-bottom on .rule-form-field | Custom class overriding Bootstrap form-group spacing |
| Dark mode tint completeness | Extended palette tints missing from dark mode |
| BvConfig striped default | BTable not configured for global zebra striping |
| No raw Bootstrap CSS vars | `var(--primary)` instead of `var(--vulcan-primary)` |

## File Map

```
app/javascript/application.scss                    # Layer 1 + dark mode overrides
app/javascript/styles/triage-tints.css             # Layer 2 + 3
app/javascript/styles/field-states.css             # Lock/review state borders
app/javascript/utils/colorMode.js                  # Dark mode toggle + persistence
app/javascript/config/bootstrapVueConfig.js        # BvConfig global defaults
app/javascript/components/shared/PanelLayout.vue   # Multi-panel layout component
spec/config/design_system_audit_spec.rb            # TDD guard tests
```

## Dark Mode Component Overrides

All dark mode overrides live in the `[data-bs-theme="dark"]` block in `application.scss`. Light mode is never touched.

### The pattern (Bootstrap 5.3 port)

Variant colors use ONE `@each` loop with shared Sass `mix()` formulas. Never add individual `.badge-warning`, `.btn-outline-info` etc. blocks — the loop handles all variants.

```scss
// Inside [data-bs-theme="dark"] { ... }
$dark-variants: (primary: $primary, secondary: $secondary, success: $success,
                 danger: $danger, warning: $warning, info: $info);

@each $variant, $color in $dark-variants {
  $dark-text: mix(white, $color, 40%);   // BS5.3: tint-color($color, 40%)
  $dark-bg:   mix(black, $color, 60%);   // BS5.3: shade-color($color, 80%)

  .btn-outline-#{$variant} { color: $dark-text; border-color: $dark-text; }
  .badge-#{$variant} { background-color: $dark-bg; color: $dark-text; }
}
```

### Rules

1. Variables in `:root` (light) + overrides in `[data-bs-theme="dark"]` — never global `!important` unless matching BootstrapVue specificity
2. Use Sass `mix()` not hardcoded hex — formulas track Bootstrap 5.3 source
3. Specificity must beat BootstrapVue selectors (e.g., `.b-toast-solid .toast` needs `(0,4,0)`)
4. Regression tests in `spec/config/design_system_audit_spec.rb` enforce DRY (`@each` loops, no individual variant blocks)
5. Reference: https://getbootstrap.com/docs/5.3/customize/color-modes/
