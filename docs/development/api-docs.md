# API Documentation

Vulcan's API is documented in two places:

1. **In-app reference** — Scalar viewer at `/api/docs` (behind authentication)
2. **Public reference** — Auto-generated at [vulcan.mitre.org/api/overview](https://vulcan.mitre.org/api/overview) using [vitepress-openapi](https://github.com/enzonotario/vitepress-openapi)

Both are driven by the same OpenAPI 3.2 spec at `doc/openapi/`.

## OpenAPI Commands

| Command | Output | Purpose |
|---------|--------|---------|
| `yarn openapi:bundle` | `doc/openapi.yaml` | Bundle multi-file YAML for Rails app + Scalar |
| `yarn openapi:lint` | stdout | Validate spec (broken $refs, unused schemas) |
| `yarn openapi:docs` | `docs/data/openapi.json` | Bundle as JSON for VitePress public docs |

## Updating the Spec

After editing any file in `doc/openapi/`:

```bash
yarn openapi:bundle && yarn openapi:lint
git add doc/openapi.yaml
```

A lefthook pre-commit hook (`openapi-bundle-check`) enforces this — commits that touch
`doc/openapi/**` but have a stale `doc/openapi.yaml` will be rejected.

## Public API Reference (VitePress)

The public docs at [vulcan.mitre.org](https://vulcan.mitre.org) auto-generate per-endpoint
pages from the spec using [vitepress-openapi](https://github.com/enzonotario/vitepress-openapi).
Each endpoint gets its own page with parameters, response schemas, code samples (cURL,
JavaScript, PHP, Python), and an interactive playground.

To preview locally:

```bash
yarn openapi:docs         # Generate docs/data/openapi.json
cd docs && yarn dev       # Preview at localhost:5173
```

In CI, the `docs.yml` workflow runs `yarn openapi:docs` automatically when spec files
change. The generated `docs/data/openapi.json` is gitignored — built fresh on every deploy.

The spec is also published to the [Scalar Registry](https://registry.scalar.com/@mitre/apis/vulcan/latest)
on each release via the `release.yml` workflow.

## In-App API Docs (Scalar)

Vulcan serves interactive API documentation at `/api/docs` using [Scalar](https://scalar.com).
This is behind `authenticate_user!` — only logged-in users can access it.

### Architecture

```
app/views/api_docs/show.html.haml     # Page template + CSS variable mappings
app/javascript/packs/api_docs.js      # Scalar initialization + theme sync
app/controllers/api_docs_controller.rb # Serves page + OpenAPI spec YAML
doc/openapi.yaml                       # Bundled OpenAPI spec (generated)
```

### Theme Integration

Scalar's colors are mapped to Vulcan's design system variables so the API docs
match the rest of the application in both light and dark mode.

1. **CSS variable mapping** — The HAML template maps Scalar's `--scalar-*` variables
   to Vulcan's `--vulcan-*` variables using `var()` references.

2. **Body class sync** — A `MutationObserver` in `api_docs.js` watches `[data-bs-theme]`
   and toggles `.dark-mode` / `.light-mode` on `<body>`.

3. **Scalar's own toggle hidden** — `hideDarkModeToggle: true` in the config.

### Variable Mapping

| Scalar Variable              | Vulcan Variable              | Purpose            |
|------------------------------|------------------------------|---------------------|
| `--scalar-color-1`           | `--vulcan-body-color`        | Primary text        |
| `--scalar-color-2`           | `--vulcan-secondary-color`   | Secondary text      |
| `--scalar-color-accent`      | `--vulcan-primary`           | Brand/accent color  |
| `--scalar-background-1`      | `--vulcan-body-bg`           | Page background     |
| `--scalar-background-2`      | `--vulcan-secondary-bg`      | Elevated surfaces   |
| `--scalar-background-3`      | `--vulcan-tertiary-bg`       | Inset/recessed      |
| `--scalar-background-accent` | `--vulcan-primary-tint`      | Accent tint         |
| `--scalar-border-color`      | `--vulcan-border-color`      | Borders             |

### Configuration

All Scalar configuration is in `app/javascript/packs/api_docs.js`:

- **`theme: "kepler"`** — Scalar's default dark theme preset (CSS overrides replace its colors)
- **`darkMode`** — Initial state read from `[data-bs-theme]`
- **`customFetch`** — Sends `credentials: "include"` for same-origin requests only
- **`onBeforeRequest`** — Injects the Rails CSRF token on mutation requests

### Authentication

The in-app Scalar viewer loads the spec from the [Scalar Registry](https://registry.scalar.com/@mitre/apis/vulcan/latest).
Session cookie authentication is used for the "Try it" button via `customFetch` with
`credentials: "include"` on same-origin requests. Cross-origin requests (registry fetch)
do not send credentials to avoid CORS conflicts.
