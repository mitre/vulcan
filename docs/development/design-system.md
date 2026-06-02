# Vulcan Design System

Vulcan uses a 4-layer CSS custom property architecture for theming and dynamic coloring. This system supports dark mode, triage status colors, and consistent palette usage across all Vue components.

## Architecture

```
Layer 1: --vulcan-*         Bootstrap Sass → CSS custom properties (application.scss)
Layer 2: --triage-*         Semantic mapping: triage status → core color (triage-tints.css)
Layer 3: [data-triage]      Data-attribute selectors → intermediate vars (triage-tints.css)
Layer 4: .component-class   ONE CSS rule reads intermediate vars (per-component)
```

Each layer references only the layer above. Adding a new status or changing a color is a single edit at the appropriate layer.

## Layer 1: Core Palette (`application.scss`)

Bridges Bootstrap 4 Sass variables to CSS custom properties at `:root`. Bootstrap 4 compiles Sass to hardcoded hex — these variables make the palette available as runtime design tokens.

```scss
:root {
  --vulcan-primary: #{$primary};
  --vulcan-primary-tint: #{rgba($primary, 0.10)};
  --vulcan-primary-text: #{color-yiq($primary)};
  // ... success, danger, warning, info, light, dark, purple, teal, indigo
}
```

**Convention:** `--vulcan-{color}` (solid), `--vulcan-{color}-tint` (background), `--vulcan-{color}-text` (contrast text).

### Color Reference

#### Core Theme Colors (Bootstrap 4 defaults)

| Variable | Color | Hex | Usage |
|----------|-------|-----|-------|
| `--vulcan-primary` | <ColorSwatch color="#007bff" /> Blue | `#007bff` | Links, active states, concur-with-comment triage |
| `--vulcan-secondary` | <ColorSwatch color="#6c757d" /> Gray 600 | `#6c757d` | Muted text, pending triage |
| `--vulcan-success` | <ColorSwatch color="#28a745" /> Green | `#28a745` | Success toasts, concur triage |
| `--vulcan-danger` | <ColorSwatch color="#dc3545" /> Red | `#dc3545` | Error toasts, non-concur triage |
| `--vulcan-warning` | <ColorSwatch color="#ffc107" /> Yellow | `#ffc107` | Warning toasts, informational triage |
| `--vulcan-info` | <ColorSwatch color="#17a2b8" /> Cyan | `#17a2b8` | Info toasts, badges |
| `--vulcan-light` | <ColorSwatch color="#f8f9fa" /> Gray 100 | `#f8f9fa` | Light backgrounds |
| `--vulcan-dark` | <ColorSwatch color="#343a40" /> Dark | `#343a40` | Dark text, dark backgrounds |

#### Extended Palette (triage-specific)

| Variable | Color | Hex | Triage Status |
|----------|-------|-----|---------------|
| `--vulcan-purple` | <ColorSwatch color="#6f42c1" /> Purple | `#6f42c1` | Withdrawn |
| `--vulcan-teal` | <ColorSwatch color="#20c997" /> Teal | `#20c997` | Duplicate |
| `--vulcan-indigo` | <ColorSwatch color="#6610f2" /> Indigo | `#6610f2` | Addressed By |

#### Dark Mode

In dark mode (`[data-bs-theme="dark"]`), colors are lightened ~15% for contrast on dark backgrounds. The gray scale inverts (100↔900). All `--vulcan-*-tint` opacity values increase to maintain legibility.

### Dark Mode Overrides

The `[data-bs-theme="dark"]` selector overrides Layer 1 values for dark mode. Bootstrap 5.3 pattern applied to Bootstrap 4.6.2:

```scss
[data-bs-theme="dark"] {
  --vulcan-primary: #{lighten($primary, 15%)};
  --vulcan-primary-tint: #{rgba(lighten($primary, 15%), 0.15)};
  // gray scale inverts: 100↔900
}
```

All downstream layers (2, 3, 4) automatically adapt — they reference `var(--vulcan-*)`, not hardcoded values.

## Layer 2: Semantic Mapping (`triage-tints.css`)

Maps triage status names to core palette colors. This is the single source of truth for "what color is concur?"

```css
:root {
  --triage-concur: var(--vulcan-success);
  --triage-concur-tint: var(--vulcan-success-tint);
  --triage-non-concur: var(--vulcan-danger);
  --triage-pending: var(--vulcan-secondary);
  --triage-withdrawn: var(--vulcan-purple);
  --triage-duplicate: var(--vulcan-teal);
  --triage-addressed-by: var(--vulcan-indigo);
}
```

**Palette rationale** (ISO 3864 + USWDS): green = accepted, blue = accepted with changes, red = declined, yellow = informational, grey = inactive/terminal.

## Layer 3: Data-Attribute Selectors (`triage-tints.css`)

Components set `data-triage="status"` on elements. Layer 3 maps each status to intermediate CSS variables:

```css
[data-triage="concur"] {
  --status-color: var(--triage-concur);
  --status-tint: var(--triage-concur-tint);
  --status-fg: var(--triage-concur-text);
  --status-pill-fg: var(--triage-concur-text);
}
```

**Adding a new triage status:** add ONE `[data-triage="new_status"]` block here. Zero component changes.

## Layer 4: Component Consumption

Components read the intermediate variables. One CSS rule per pattern:

```css
.triage-bg[data-triage] {
  background-color: var(--status-tint) !important;
  border-left-color: var(--status-color) !important;
}
```

Vue components set the attribute: `<div :data-triage="review.triage_status" class="triage-bg">`.

## Dark Mode Toggle

`app/javascript/utils/colorMode.js` manages the theme:

- **Detection:** checks `localStorage` first, then `prefers-color-scheme` media query
- **Storage:** `localStorage` key `vulcan-theme` persists across sessions
- **Application:** sets `data-bs-theme` attribute on `<html>` element
- **Toggle:** navbar button calls `toggleTheme()` which swaps light↔dark

```javascript
import { initTheme, toggleTheme } from "../utils/colorMode";
initTheme();                    // On page load — apply stored/preferred theme
toggleTheme();                  // On button click — swap and persist
```

## Rules for Contributors

1. **Never hardcode hex colors** in Vue components or SCSS — use `var(--vulcan-*)` or `var(--triage-*)`
2. **Never use `rgba()` with hardcoded colors** — use the `*-tint` variables
3. **New triage status?** Add one block to Layer 3 in `triage-tints.css`. Done.
4. **New non-triage color?** Add to Layer 1 in `application.scss` `:root` block
5. **Dark mode opacity:** use `>= 0.85` for WCAG contrast compliance
6. **Bootstrap 4 gotcha:** use `mix(white, $color, %)` not `tint-color()` (Bootstrap 5 function)
7. **Test dark mode:** toggle the navbar switch and verify every changed component

## File Map

```
app/javascript/application.scss           # Layer 1: --vulcan-* + dark mode overrides
app/javascript/styles/triage-tints.css    # Layer 2 + 3: --triage-* + [data-triage]
app/javascript/utils/colorMode.js         # Toggle logic + localStorage persistence
```
