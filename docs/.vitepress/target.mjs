// What differs between builds of this documentation, in one place.
//
// Shaped after VitePress's own `locales` table: shared configuration stays in
// config.mjs, and each entry here declares ONLY what that target overrides.
// The discipline that keeps this honest is the same one VitePress states for
// locales — if a value is the same everywhere, it does not belong here. The
// moment an entry starts to look like a whole configuration, it has become a
// second source of truth.
//
// Unlike locales, targets are selected at BUILD time and are mutually
// exclusive: locales all ship in one output and are chosen by URL, whereas the
// in-app build must not carry the public site's placeholder credentials and
// the public build must not advertise same-origin cookie authentication.

const PUBLIC_API = {
  // Cookie auth is meaningless to a reader who is not inside an instance, and
  // the same-origin server entry would point at the documentation host rather
  // than at any application.
  sameOrigin: false,
  allowCustomServer: true,
  defaultBaseUrl: 'https://vulcan.example.com',
  prefillToken: 'Token vulcan_your_token_here'
}

const TARGETS = {
  // Published to the documentation domain.
  pages: {
    base: '/',
    inApp: false,
    // Outbound chrome — the GitHub edit link, the social icons, the external
    // training nav entry, and the landing hero's external actions — is
    // meaningful only where the internet is: served in-app (possibly
    // airgapped) every one of those links is dead.
    outboundChrome: true,
    api: PUBLIC_API
  },

  // A developer preview served from a subpath.
  local: {
    base: '/vulcan/',
    inApp: false,
    outboundChrome: true,
    api: PUBLIC_API
  },

  // Served by the application itself. The mount path is the application's
  // fact — it is what defines the route — so it is passed in rather than
  // restated here.
  app: {
    base: process.env.VULCAN_DOCS_BASE || '/docs/',
    inApp: true,
    outboundChrome: false,
    api: {
      // The reader is already inside the instance, so their session
      // authenticates them and the API is same-origin.
      //
      // "Same-origin" has to become a real absolute URL at request time. The
      // playground builds its request as `${server}${path}` and hands it to
      // `new URL()` with no base, which rejects anything relative — a server
      // of "/" yields "//api/..." and throws before any request is made. The
      // origin is only knowable in the browser, so the theme resolves it
      // there rather than baking a hostname into the build.
      sameOrigin: true,
      // Pointing the playground at another host from inside a running
      // instance is a footgun, not a feature.
      allowCustomServer: false,
      defaultBaseUrl: null,
      prefillToken: null
    }
  }
}

export const TARGET_NAMES = Object.keys(TARGETS)

export function resolveTarget(name = process.env.VULCAN_DOCS_TARGET) {
  const resolved = TARGETS[name || 'local']

  if (!resolved) {
    throw new Error(
      `Unknown documentation target ${JSON.stringify(name)}. Expected one of: ${TARGET_NAMES.join(', ')}`
    )
  }

  return { name: name || 'local', ...resolved }
}

export const target = resolveTarget()
