# API Documentation

Vulcan's browsable API reference is part of this documentation site, auto-generated
from the OpenAPI spec by [vitepress-openapi](https://github.com/enzonotario/vitepress-openapi):

1. **In-app reference** — the documentation site ships inside the application at `/docs`,
   so the reference lives at `/docs/api/overview` and works in airgapped deployments
   with no external requests. The old `/api/docs` viewer URL permanently redirects there.
2. **Public reference** — the same site published at
   [vulcan.mitre.org/api/overview](https://vulcan.mitre.org/api/overview)

Both are driven by the same OpenAPI 3.2 spec at `doc/openapi/`.

## OpenAPI Commands

| Command | Output | Purpose |
|---------|--------|---------|
| `yarn openapi:bundle` | `doc/openapi.yaml` | Bundle multi-file YAML for the app's `/openapi.yaml` endpoint |
| `yarn openapi:lint` | stdout | Validate spec (broken $refs, unused schemas) |
| `yarn openapi:docs` | `docs/site/data/openapi.json` + `docs/site/public/api/openapi.{json,yaml}` | Bundle as JSON for the reference pages and place the downloadable copies the site links |

## Updating the Spec

After editing any file in `doc/openapi/`:

```bash
yarn openapi:bundle && yarn openapi:lint
git add doc/openapi.yaml
```

A lefthook pre-commit hook (`openapi-bundle-check`) enforces this — commits that touch
`doc/openapi/**` but have a stale `doc/openapi.yaml` will be rejected.

## The Generated Reference

The reference pages are auto-generated from the spec: each endpoint gets its own page
with parameters, response schemas, code samples (cURL, JavaScript, PHP, Python), and an
interactive playground. The playground sends same-origin requests, so in the in-app
copy a signed-in reader's session applies to read operations; write operations need a
Personal Access Token — the same credential a scripted consumer uses.

To preview locally:

```bash
yarn openapi:docs         # Generate docs/site/data/openapi.json + downloadable copies
cd docs && yarn dev       # Preview at localhost:5173
```

In CI, the `docs.yml` workflow runs `yarn openapi:docs` automatically when spec files
change. The generated files are gitignored — built fresh on every deploy.

## Machine-Readable Spec

Every Vulcan instance serves the bundled spec at the OpenAPI-recommended root
filenames, `/openapi.yaml` and `/openapi.json` (`ApiDocsController`). The
documentation site also ships downloadable copies at `/api/openapi.json` and
`/api/openapi.yaml`, linked from the [API overview](/api/overview) page.
