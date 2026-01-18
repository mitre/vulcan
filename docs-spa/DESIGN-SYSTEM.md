# Vulcan Design System

CSS Custom Properties - Single Source of Truth for layout, spacing, and component styling.

## Location

All design tokens are defined in `app/javascript/application.scss` under the `:root` selector.

## Design Token Categories

### 1. Breakpoints (for JavaScript Access)

Bootstrap 5 breakpoints exposed as CSS variables for Vue/JavaScript access:

```css
--app-breakpoint-xs: 0;
--app-breakpoint-sm: 576px;
--app-breakpoint-md: 768px;
--app-breakpoint-lg: 992px;
--app-breakpoint-xl: 1200px;
--app-breakpoint-xxl: 1400px;
```

**Note**: CSS variables cannot be used in `@media` queries. Use Bootstrap's Sass mixins (`@include media-breakpoint-up(sm)`) for media queries.

**JavaScript Access**:
```typescript
const breakpoint = getComputedStyle(document.documentElement)
  .getPropertyValue('--app-breakpoint-md')
  .trim()
```

### 2. Layout Dimensions

Core fixed heights:
```css
--app-navbar-height: 56px;
--app-footer-height: 40px;
--app-page-header-height: 56px;
```

Derived heights (calculated):
```css
--app-main-height: calc(100vh - var(--app-navbar-height) - var(--app-footer-height));
--app-content-height: calc(var(--app-main-height) - var(--app-page-header-height));
```

Sidebar widths:
```css
--app-sidebar-width: 280px;
--app-sidebar-width-collapsed: 80px;
--app-sidebar-width-narrow: 250px;
--app-sidebar-right-width: 280px;
```

Container widths:
```css
--app-container-max-width: 1600px;
```

### 3. Z-Index Scale

Standardized z-index values (aligned with Bootstrap 5):

| Token | Value | Usage |
|-------|-------|-------|
| `--app-z-dropdown` | 1000 | Dropdown menus |
| `--app-z-sticky` | 1020 | Sticky headers |
| `--app-z-fixed` | 1030 | Fixed position elements |
| `--app-z-modal-backdrop` | 1040 | Modal backdrop |
| `--app-z-offcanvas` | 1045 | Offcanvas panels |
| `--app-z-modal` | 1050 | Modal dialogs |
| `--app-z-popover` | 1070 | Popovers |
| `--app-z-tooltip` | 1080 | Tooltips |
| `--app-z-command-palette` | 1090 | Command palette (highest) |

### 4. Spacing Scale

Matches Bootstrap's spacing scale:

```css
--app-spacing-0: 0;
--app-spacing-1: 0.25rem;   /* 4px */
--app-spacing-2: 0.5rem;    /* 8px */
--app-spacing-3: 1rem;      /* 16px */
--app-spacing-4: 1.5rem;    /* 24px */
--app-spacing-5: 3rem;      /* 48px */
```

### 5. Transition Timing

```css
--app-transition-fast: 150ms;
--app-transition-base: 300ms;
--app-transition-slow: 500ms;
--app-transition-ease: cubic-bezier(0.4, 0, 0.2, 1);
```

## Layout Utility Classes

### `.container-app`
Applies max-width constraint for standard pages.

```html
<div class="container-fluid container-app">
  <!-- Content constrained to 1600px -->
</div>
```

### `.footer`
Enforces consistent footer height.

### `.main-content`
Sets height to fill available space between navbar and footer.

## Container Query System

Container queries allow components to respond to their container's size rather than the viewport.

### Enabling Container Queries

Add a container class to the parent element:

```html
<!-- Generic container -->
<div class="cq-container">
  <MyComponent />
</div>

<!-- Named containers for specific contexts -->
<div class="cq-sidebar">...</div>
<div class="cq-card">...</div>
<div class="cq-modal">...</div>
<div class="cq-editor">...</div>
```

### Using Container Queries in Components

```vue
<style scoped>
/* Respond to container width */
@container (max-width: 500px) {
  .my-component {
    flex-direction: column;
  }
}

/* Named container query */
@container sidebar (max-width: 299px) {
  .sidebar-item {
    /* Collapsed sidebar styles */
  }
}
</style>
```

### Container Query Breakpoints

Container breakpoints are intentionally smaller than viewport breakpoints:

| Tier | Width | Usage |
|------|-------|-------|
| xs | 0-299px | Very narrow (collapsed sidebar, small modal) |
| sm | 300-499px | Narrow (sidebar, card) |
| md | 500-699px | Medium (panel, modal) |
| lg | 700-899px | Wide (main content panel) |
| xl | 900px+ | Full (large modal, full-width content) |

### Browser Support

Container queries are supported in all major browsers since February 2023.

For legacy browser fallback:
```css
@supports not (container-type: inline-size) {
  @media (max-width: 768px) {
    /* Fallback media query styles */
  }
}
```

## App Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│  <BApp class="d-flex flex-column vh-100">                   │
├─────────────────────────────────────────────────────────────┤
│  <header class="flex-shrink-0 sticky-top">                  │
│    Navbar (56px)                                            │
├─────────────────────────────────────────────────────────────┤
│  <main class="flex-grow-1 overflow-hidden">                 │
│    RouterView                                               │
│    ├── PageContainer (standard pages)                       │
│    └── Direct content (full-height pages like editors)      │
├─────────────────────────────────────────────────────────────┤
│  <AppFooter class="footer flex-shrink-0">                   │
│    Footer (40px)                                            │
└─────────────────────────────────────────────────────────────┘
```

## Page Patterns

### Standard Pages (PageContainer)
For list views, dashboards, forms:

```vue
<template>
  <PageContainer>
    <!-- Content scrolls within container -->
  </PageContainer>
</template>
```

### Full-Height Pages (Editor/Viewer)
For pages that need precise height control:

```vue
<template>
  <div class="d-flex flex-column" style="height: var(--app-main-height);">
    <!-- Page header -->
    <div class="flex-shrink-0">...</div>
    <!-- Content area fills remaining space -->
    <div class="flex-grow-1 overflow-hidden">...</div>
  </div>
</template>
```

## Technical Debt

### Legacy Components
Some Vue 2 Options API components (RuleNavigator, DiffViewer) use runtime `getBoundingClientRect()` calculations instead of CSS variables. These work correctly but should be refactored to CSS variable approach during Vue 3 migration.

## Related Files

- `app/javascript/application.scss` - Design token definitions
- `app/javascript/App.vue` - Root layout structure
- `app/javascript/components/shared/AppFooter.vue` - Footer component
- `app/javascript/components/shared/PageContainer.vue` - Standard page wrapper
