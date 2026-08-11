# In-app documentation on VitePress

Replace the hand-built in-app guide pipeline with the VitePress site, built during the
image build and served by Rails at its own route.

## Why

Two renderers exist for one body of content. The VitePress site renders `docs/` for the
public website; `DisaGuideController` re-renders five of those markdown files in-app with
a bespoke pipeline — it strips VitePress frontmatter, hand-converts `::: info` callouts,
extracts its own table of contents, and carries a duplicated navigation list in
`PAGE_SECTIONS`. That second renderer parses another tool's dialect with its own parser
and will drift from the site it is imitating.

A second, sharper reason: the in-app API reference at `/api/docs` loads Scalar from
`https://cdn.jsdelivr.net`, so it does not work in an airgapped deployment at all.

## Decisions

Settled in discussion; recorded here rather than re-opened.

1. **Take the pattern, not the gem.** `Switchdreams/vitepress-rails` (MIT, v0.2.0)
   demonstrates the right architecture — build during `assets:precompile`, serve the
   output through a Rails route. It is not adopted as a dependency: its controller
   subclasses `ActionController::Base` so the application's authentication never runs,
   and it pins `high_voltage ~> 3.1`, a 2019 release, against our Rails 8.1.
   Both load-bearing pieces would need replacing, leaving a short rake task we prefer
   to own.
2. **A new route.** The built site is served at its own path, not layered onto the
   existing `/disa-guide` endpoint.
3. **Public by default, switchable.** Access is governed by one setting in
   `config/vulcan.default.yml`, defaulting to public. The reason for the setting is
   structural, not speculative: serving from `public/` is unreachable by Rails routing,
   so a deployment that later wants the docs gated could not get there without rebuilding
   the serving mechanism. The controller design keeps both outcomes one setting apart.
4. **The whole build is served through the controller**, HTML and assets alike. The
   reference implementation splits them — HTML through Rails, assets into `public/` —
   which would leave every image and script publicly fetchable even when the setting says
   private. Half-private is worse than either choice. A documentation site's request
   volume does not justify the split.
5. **Scope is the whole user-facing site**, not only the five DISA process pages. This
   supersedes the 2026-07-25 note on the card, which limited scope to the existing in-app
   guides. `srcExclude` in `docs/.vitepress/config.mjs` already keeps `plans`, `research`,
   and `superpowers` out of the build, so internal engineering notes are not included.
6. **The old pipeline is retired**, not left alongside. Deleting its files requires
   explicit approval and happens only after the embedded site demonstrably serves every
   page the old one served.
7. **The site is not wrapped in application chrome. It carries the logo, the application's
   colors, and a link back.** The served pages are VitePress's own complete documents, so
   there is no application shell to render them inside. Two alternatives were rejected on
   existing constraints rather than taste: an iframe requires relaxing `frame_src :none`,
   which the policy forbids; extracting the markup into a view means re-creating the
   bespoke renderer this work exists to delete. Replicating the full navigation bar was
   also rejected — it would be a second navigation to keep in visual sync and could not
   show live state such as the user menu. Note that the application is server-rendered
   pages with per-page Vue instances, so every navigation is already a full page load;
   a themed document is no sharper a break than moving between existing pages.

8. **Reads authenticate by session, writes require a token, and no CSRF plumbing is
   built.** Verified against the documentation tool's own source rather than assumed:
   its playground calls `fetch` with no `credentials` option, so the browser default of
   same-origin applies and a signed-in reader's cookie is sent — read-only requests work
   with no configuration at all. Mutations do not, because the application rejects
   session-authenticated writes without a CSRF token, and the playground has no hook for
   an arbitrary default header: its security-scheme defaults are a closed set keyed to
   schemes declared in the specification. Forcing it would mean declaring CSRF as a
   fictitious security scheme in a published specification, or patching the library.
   Neither is worth doing, and the protection is behaving correctly — mutating a live
   instance from a documentation playground on ambient credentials is the thing it
   exists to prevent. A personal access token is the honest path for writes and is the
   same credential a scripted consumer needs. Because the pages are served by a
   controller, a signed-out reader can be shown a sign-in link rather than an
   unexplained 401.

9. **Publishing is structural, and final validation runs once against the final
   layout** (ruled 2026-08-10). The site builds from a dedicated site root
   (positive selection): everything under it is published, everything outside it
   cannot be, and `srcExclude` is deleted so curation has exactly one mechanism.
   This replaced exclude-pattern curation after it shipped a live defect — the
   decisions tree was published because the exclude list never named it, against
   the standing ruling that plans and decisions stay unpublished. Per-target
   presentation (theme, branding, hero action) lives in the target table as
   locales-style deltas over the one content tree — the same pattern the site
   generator uses for internationalization. Sequencing follows from
   validate-once: reorganization, then theming, then the navigation entry, then
   the old pipeline's retirement, and only then the production-image capstone
   (airgap proof and stated size), so the image validation measures the final
   desired state instead of an intermediate one. The whole chain lands before
   the merge.

## Mechanism

Build, in the existing build stage:

- `docs/.vitepress/config.mjs` gains a third base mode. It already switches between `/`
  for GitHub Pages and `/vulcan/` otherwise; the in-app build sets the route's base.
- A rake task builds the site and places the output where the controller reads it. The
  task hooks onto `assets:precompile`, which the image build already runs, so no new
  build step is introduced to the Dockerfile.
- Output is generated, not committed, and is excluded from the build context.

Serve:

- One route mounts the docs path; one controller reads from the build output and returns
  each file with its correct content type. `cleanUrls: true` means requests arrive without
  a `.html` extension and the controller resolves that.
- The authentication gate is conditional on the setting. Everything else about the
  controller is the same in both modes.

## Open technical risk — CSP

`config/initializers/content_security_policy.rb` sets `script_src :self, :unsafe_eval,
https://cdn.jsdelivr.net` with no `unsafe_inline`. VitePress emits an inline theme-init
script that runs before paint; under the current policy it is blocked.

The intended approach is a per-request nonce applied to the served HTML, which is
available precisely because the controller owns the response body. A build-time hash
allowlist is the alternative. The application-wide policy is not weakened to accommodate
the docs path; if neither approach works cleanly, the options go back to the owner rather
than the policy being relaxed.

Retiring Scalar removes `cdn.jsdelivr.net`, `api.scalar.com`, `registry.scalar.com`, and
`fonts.scalar.com` from the policy — a reduction in external origins and a prerequisite
for the API reference working offline.

## Size

The current local build is 51M: `api` 23M, `assets` 20M, `attachments` 2.4M, everything
else under 1M each. The API reference and its bundles are therefore about 43M of the
total. Shipping it is the point — it is what makes API documentation work without a CDN —
but the number is large enough that trimming what the API section emits belongs in scope,
with the accepted figure stated rather than discovered later.

For comparison, the interim fix ships 3.1M of DISA markdown and attachments for the old
pipeline. That interim shipping stops when this work lands.

## Migration inventory

Produced by a mechanical sweep plus two independent reviews, then verified command by
command. It exists because the work was accreting one discovered item at a time, which
is the symptom of not knowing the scope.

**Already fixed, in the commits that carry this work.** Three defects sat in the seam
between cards, where each card verified itself in isolation and nothing tested the
combination: the production image built the documentation site and then deleted it,
because the prune ran in the same instruction as the precompile that produced it; the
prune guard listed the built site among the paths it required to be removed, so it would
have enforced that deletion; and the build never generated the bundled OpenAPI
description it hard-imports, which works only on a machine where a previous run left the
file behind. Alongside them, two pre-existing defects that the migration made
load-bearing: both cleanup instructions ended in `|| true`, which binds to the whole
`&&` chain and meant asset precompilation could fail while the image still built
successfully; and eight documentation pages are symlinks to root markdown that the
build context excluded, so they dangled the moment anything read them.

**Inbound references to the guide**, all of which move or die with it: the navigation
helper, a deep link from the rules editor toolbar, the pack entry point, an initialiser
module, the Vue page and its spec, the request spec, four entries in the authorization
coverage list, and this plan's own prune guard, which derives a path from the controller
constant.

**A second navigation source.** The JSON navigation served to the front end declares its
own copy of the menu, with a link that has never matched the route — an underscore where
the route has a hyphen. Its request spec and contract test both assert on the menu's
contents and count.

**The API reference is more than one page.** Three routes serve the specification itself
in different formats to tooling rather than browsers; a redirect to HTML would fail a
client asking for JSON. The error envelope's documentation base points at a path under
the viewer, stamped into the machine-readable type of every error the API returns, and
pinned by roughly a hundred assertions. That path has never resolved to a real page.

**Content that misleads a reader inside a running instance**, distinct from anything
structural: a page describing shipped export modes as planned and shipped behaviour as
broken; the API overview walking through a server picker the in-app build does not
render; the fact that writes need a token recorded only in a code comment; a maintainer
runbook, built and searchable, instructing readers to edit a controller that is being
deleted; and the first entry under Get Started sending users to a hosted deployment.

**Publishing is opt-out, and that is the underlying defect.** Directories are included
unless someone remembers to exclude them. Ten decision records and fourteen new
contributor pages become published the moment this branch merges, which nobody decided.
Twenty-six tracker references sit in ten of those files, against the standing rule that
internal references stay out of artifacts.

## Phases

(Ordering revised 2026-08-10 per decision 9 — the pre-merge chain after the serving
foundation is: site-root reorganization → theme → navigation entry → retirement →
production-image capstone, so final validation measures the final layout once.)

1. Base mode and build task — the site builds to a known location during
   `assets:precompile`, output excluded from the build context. (Done.)
2. Route, controller, and the access setting — the built site is reachable, with the
   gate honoring the setting in both positions. (Done.)
3. CSP — the served pages run their scripts under the existing policy, unweakened.
   (Done.)
4. Site-root reorganization — publishing becomes structural (decision 9): the curated
   site root replaces srcExclude, unpublished trees sit outside it, and every path
   consumer (guide controller, image prune, workflows) follows the move.
5. Theme — the logo, the application's colors, and a link back, applied through the
   documentation theme's own extension point rather than by post-processing its
   output; per-target presentation deltas live in the target table.
6. Navigation entry — both menu sources point at the served site, single entry.
7. Retire the old pipeline — redirects from the existing guide paths, then removal of
   the controller, its view, its Vue page and pack, and their specs.
8. Production image, the capstone — the build ships, an airgapped container serves the
   site with no external requests, and the image size is measured and stated against
   the final layout.
9. API reference (post-merge) — the built reference replaces the CDN-loaded page, and
   the freed origins come out of the CSP.
