import { defineConfig } from "vitepress";
import { ViteImageOptimizer } from "vite-plugin-image-optimizer";
import { useSidebar } from "vitepress-openapi";
import spec from "../site/data/openapi.json" with { type: "json" };
import { target } from "./target.mjs";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Vulcan",
  description: "Security Technical Implementation Guide (STIG) creation and validation platform",
  // Every per-target difference is declared in target.mjs, selected by
  // VULCAN_DOCS_TARGET at build time. Nothing else in this file re-derives it.
  base: target.base,

  // Publishing is structural: only content under the site root builds, so a
  // tree outside it cannot be published and there is no exclude list to
  // forget. The curation guard spec pins this against the built output.
  srcDir: 'site',

  // Clean URLs without .html extension
  cleanUrls: true,

  // Last updated time
  lastUpdated: true,

  // Head tags. Entries here are emitted VERBATIM — VitePress rebases markdown
  // links and bundled assets under `base`, but never these — so every href must
  // carry the target base itself or it 404s on any non-root deployment. (The
  // favicon appeared to work in-app only because the Rails app happens to ship
  // a file of the same name at its own root.)
  head: [
    // Match Vulcan's main app and saf-site — all three use the same saf-logo.svg
    ["link", { rel: "icon", type: "image/svg+xml", href: `${target.base}saf-logo.svg` }],
    ["link", { rel: "apple-touch-icon", sizes: "180x180", href: `${target.base}saf-logo-180.png` }],
    ["meta", { name: "theme-color", content: "#005288" }],
    // Served in-app the pages wear the application's palette and dark-mode
    // surfaces. The overrides live in a public stylesheet linked only by this
    // build-time entry, so the published targets never load it and the shared
    // theme stays one code path.
    ...(target.inApp
      ? [["link", { rel: "stylesheet", href: `${target.base}in-app-theme.css` }]]
      : []),
  ],

  // The landing hero is shared content; what differs in-app is one action.
  // This is the generator's own build-time hook — the served HTML is never
  // post-processed. Ruling: in-app, "Try Production" becomes "Go to Vulcan"
  // pointing at the application root — the reader is already inside the
  // instance the button used to advertise.
  //
  // The link is "/../" because the theme rebases every internal href under
  // the site base: "/" would render as the site's own root, while "/../"
  // renders as `${base}../`, which the browser resolves to the application
  // root. target: "_self" rides through to the anchor, which is what stops
  // the site's SPA router from intercepting a destination outside its base.
  transformPageData(pageData) {
    // Dynamic routes: frontmatter moustaches never interpolate, so the
    // generated API pages hand their titles through route params — without
    // this, every built API page bakes literal template syntax into <title>.
    if (pageData.params?.pageTitle) {
      pageData.title = pageData.params.pageTitle;
    }

    if (!target.inApp || pageData.relativePath !== "index.md") return;

    for (const action of pageData.frontmatter.hero?.actions || []) {
      if (action.text === "Try Production") {
        action.text = "Go To Vulcan";
        action.link = "/../";
        action.target = "_self";
      }
    }
  },

  // Theme configuration
  themeConfig: {
    // The resolved target travels to the browser bundle here — the same route
    // VitePress uses to carry per-locale values to components. The theme reads
    // it from siteData and from useData().theme rather than re-deriving
    // anything from the environment, which it could not reach in any case.
    docsTarget: target,

    // Logo in nav bar
    logo: "/logo.svg",

    // Navigation bar
    nav: [
      // Served in-app, the way back to the application leads the menu. The
      // link is "/../" because the theme rebases every internal href under
      // the site base — it renders as `${base}../`, which the browser
      // resolves to the application root. target: "_self" is a no-op for the
      // browser but stops the site's SPA router from intercepting a
      // destination outside its base.
      ...(target.inApp ? [{ text: "Go To Vulcan", link: "/../", target: "_self" }] : []),
      {
        text: "User Guide",
        items: [
          {
            text: "Get Started",
            items: [
              { text: "Quick Start", link: "/getting-started/quick-start" },
              { text: "Installation", link: "/getting-started/installation" },
              { text: "Configuration", link: "/getting-started/configuration" },
              { text: "Environment Variables", link: "/getting-started/environment-variables" },
              { text: "Troubleshooting", link: "/getting-started/troubleshooting" },
            ],
          },
          {
            text: "Using Vulcan",
            items: [
              { text: "Overview", link: "/user-guide/overview" },
              { text: "Authoring Rules", link: "/user-guide/authoring-rules" },
              { text: "Sidebar — Nested Requirements", link: "/user-guide/sidebar-collapse" },
              { text: "User Management", link: "/user-guide/user-management" },
              { text: "Section Locks", link: "/user-guide/section-locks" },
              { text: "Data Management", link: "/user-guide/data-management/" },
            ],
          },
          {
            text: "Comment Triage",
            items: [
              { text: "Public Comment Review", link: "/user-guide/public-comment-review" },
              { text: "Comment Provenance", link: "/user-guide/comment-provenance" },
              { text: "Soft Redirect", link: "/user-guide/soft-redirect" },
              { text: "Move Comment", link: "/user-guide/move-comment" },
              { text: "Bulk Triage", link: "/user-guide/bulk-triage" },
              { text: "Merge Comments", link: "/user-guide/merge-comments" },
              { text: "Response Templates", link: "/user-guide/response-templates" },
              { text: "Commenter Email", link: "/user-guide/commenter-email" },
            ],
          },
          // Outbound: dead in an airgapped deployment, so declared per target.
          ...(target.outboundChrome
            ? [{ text: "SAF Training", link: "https://mitre.github.io/saf-training/courses/guidance/" }]
            : []),
        ],
      },
      {
        text: "Deployment",
        items: [
          {
            text: "Install",
            items: [
              { text: "Overview", link: "/deployment/" },
              { text: "Docker", link: "/deployment/docker" },
              { text: "Kubernetes", link: "/deployment/kubernetes" },
              { text: "Heroku", link: "/deployment/heroku" },
              { text: "Bare Metal", link: "/deployment/bare-metal" },
              { text: "Upgrade Guide", link: "/deployment/upgrade-guide" },
            ],
          },
          {
            text: "Authentication",
            items: [
              { text: "OIDC/Okta", link: "/deployment/auth/oidc-okta" },
              { text: "Login.gov (PIV/CAC)", link: "/deployment/auth/login-gov" },
              { text: "LDAP", link: "/deployment/auth/ldap" },
              { text: "GitHub OAuth", link: "/deployment/auth/github" },
            ],
          },
        ],
      },
      {
        text: "DISA Process",
        items: [
          { text: "Overview", link: "/disa-process/overview" },
          { text: "Vendor STIG Process Guide (V4R3)", link: "/disa-process/vendor-stig-process-guide" },
          { text: "Field Requirements", link: "/disa-process/field-requirements" },
          { text: "Export Requirements", link: "/disa-process/export-requirements" },
          { text: "Intent Form & Questionnaire", link: "/disa-process/intent-form" },
        ],
      },
      {
        text: "Development",
        items: [
          { text: "Setup", link: "/development/setup" },
          { text: "Documentation", link: "/development/documentation" },
          { text: "Architecture", link: "/development/architecture" },
          { text: "Authorization", link: "/development/authorization" },
          { text: "Testing", link: "/development/testing" },
          { text: "Design System", link: "/development/design-system" },
          { text: "HAML Serialization", link: "/development/haml-serialization" },
          { text: "Toast Contract", link: "/development/toast-contract" },
          { text: "API Documentation", link: "/development/api-docs" },
          { text: "OpenAPI Testing", link: "/development/openapi-testing" },
          { text: "Release Process", link: "/development/release-process" },
          { text: "Upgrade System", link: "/development/upgrade-system" },
          { text: "Port Registry", link: "/development/port-registry" },
          { text: "Contributing", link: "/CONTRIBUTING.md" },
        ],
      },
      {
        text: "API",
        items: [
          { text: "Overview", link: "/api/overview" },
          { text: "Authentication", link: "/api/authentication" },
          { text: "Errors", link: "/api/errors" },
                  ],
      },
      {
        text: "Project",
        items: [
          {
            text: "About",
            items: [
              { text: "Changelog", link: "/CHANGELOG.md" },
              { text: "Roadmap", link: "/ROADMAP.md" },
              { text: "Contributing", link: "/CONTRIBUTING.md" },
              { text: "Code of Conduct", link: "/CODE_OF_CONDUCT.md" },
              { text: "License", link: "/LICENSE.md" },
              { text: "Notice", link: "/NOTICE.md" },
            ],
          },
          {
            text: "Security",
            items: [
              { text: "Security Policy", link: "/SECURITY.md" },
              { text: "Compliance Guide", link: "/security/compliance" },
              { text: "ASD SRG Responses", link: "/security/security-controls" },
            ],
          },
        ],
      },
      {
        text: "v2.3.7",
        items: [
          { text: "Release Notes", link: "/release-notes/v2.3.7" },
          { text: "v2.3.6", link: "/release-notes/v2.3.6" },
          { text: "v2.3.5", link: "/release-notes/v2.3.5" },
          { text: "v2.3.4", link: "/release-notes/v2.3.4" },
          { text: "v2.3.1", link: "/release-notes/v2.3.1" },
          { text: "v2.2.1", link: "/release-notes/v2.2.1" },
          { text: "v2.2.0", link: "/release-notes/v2.2.0" },
          { text: "All Releases", link: "/release-notes/" },
        ],
      },
    ],

    // Sidebar navigation. Getting Started + User Guide + Comment Triage +
    // Data Management share one block so navigating between any of those
    // paths shows the full sidebar (not a section-only stub). Deployment
    // and API/Development keep their own sidebars below.
    sidebar: (() => {
      const userGuideShared = [
        {
          text: "Getting Started",
          items: [
            { text: "Quick Start", link: "/getting-started/quick-start" },
            { text: "Installation", link: "/getting-started/installation" },
            { text: "Configuration", link: "/getting-started/configuration" },
            { text: "Environment Variables", link: "/getting-started/environment-variables" },
            { text: "Troubleshooting", link: "/getting-started/troubleshooting" },
          ],
        },
        {
          text: "User Guide",
          items: [
            { text: "Overview", link: "/user-guide/overview" },
            { text: "Authoring Rules", link: "/user-guide/authoring-rules" },
            { text: "Sidebar — Nested Requirements", link: "/user-guide/sidebar-collapse" },
            { text: "User Management", link: "/user-guide/user-management" },
            { text: "Section Locks", link: "/user-guide/section-locks" },
          ],
        },
        {
          text: "Comment Triage",
          items: [
            { text: "Public Comment Review", link: "/user-guide/public-comment-review" },
            { text: "Comment Provenance", link: "/user-guide/comment-provenance" },
            { text: "Soft Redirect", link: "/user-guide/soft-redirect" },
            { text: "Move Comment", link: "/user-guide/move-comment" },
            { text: "Bulk Triage", link: "/user-guide/bulk-triage" },
            { text: "Merge Comments", link: "/user-guide/merge-comments" },
            { text: "Response Templates", link: "/user-guide/response-templates" },
            { text: "Commenter Email", link: "/user-guide/commenter-email" },
          ],
        },
        {
          text: "Data Management",
          items: [
            { text: "Overview", link: "/user-guide/data-management/" },
            { text: "Import & Export", link: "/user-guide/data-management/import-export" },
            { text: "Backup & Restore", link: "/user-guide/data-management/backup-restore" },
          ],
        },
      ];
      return {
        "/getting-started/": userGuideShared,
        "/user-guide/": userGuideShared,
        "/deployment/": [
        {
          text: "Deployment Options",
          items: [
            { text: "Overview", link: "/deployment/" },
            { text: "Docker", link: "/deployment/docker" },
            { text: "Bare Metal", link: "/deployment/bare-metal" },
            { text: "Heroku", link: "/deployment/heroku" },
            { text: "Kubernetes", link: "/deployment/kubernetes" },
            { text: "Upgrade Guide", link: "/deployment/upgrade-guide" },
          ],
        },
        {
          text: "Authentication Setup",
          items: [
            { text: "OIDC/Okta", link: "/deployment/auth/oidc-okta" },
            { text: "Login.gov (PIV/CAC)", link: "/deployment/auth/login-gov" },
            { text: "LDAP", link: "/deployment/auth/ldap" },
            { text: "GitHub OAuth", link: "/deployment/auth/github" },
          ],
        },
      ],
      "/disa-process/": [
        {
          text: "DISA STIG Process",
          items: [
            { text: "Overview", link: "/disa-process/overview" },
            { text: "Vendor STIG Process Guide (V4R3)", link: "/disa-process/vendor-stig-process-guide" },
            { text: "Field Requirements by Status", link: "/disa-process/field-requirements" },
            { text: "Export Requirements", link: "/disa-process/export-requirements" },
            { text: "Intent Form & Questionnaire", link: "/disa-process/intent-form" },
          ],
        },
      ],
      "/development/": [
        {
          text: "Development",
          items: [
            { text: "Development Setup", link: "/development/setup" },
            { text: "Documentation Guide", link: "/development/documentation" },
            { text: "DISA Guide Migration", link: "/development/disa-guide-migration" },
            { text: "Architecture", link: "/development/architecture" },
            { text: "Frontend Architecture", link: "/development/frontend-architecture" },
            { text: "State Management", link: "/development/state-management" },
            { text: "Authorization", link: "/development/authorization" },
            { text: "Section Locks", link: "/development/section-locks" },
            { text: "Rule Form Business Rules", link: "/development/rule-form-business-rules" },
            { text: "Input Length Limits", link: "/development/input-length-limits" },
            { text: "Data Management User Stories", link: "/development/data-management-user-stories" },
            { text: "Testing", link: "/development/testing" },
            { text: "Testing Pinia & Composables", link: "/development/testing-pinia-composables" },
            { text: "Test Account Safety", link: "/development/test-account-safety" },
            { text: "Seed System", link: "/development/seed-system" },
            { text: "Design System", link: "/development/design-system" },
            { text: "HAML Serialization", link: "/development/haml-serialization" },
            { text: "Toast Contract", link: "/development/toast-contract" },
            { text: "API Documentation", link: "/development/api-docs" },
            { text: "OpenAPI Testing", link: "/development/openapi-testing" },
            { text: "Release Process", link: "/development/release-process" },
            { text: "Upgrade System", link: "/development/upgrade-system" },
            { text: "Port Registry", link: "/development/port-registry" },
          ],
        },
        {
          text: "Contributing",
          items: [
            { text: "Contributing Guide", link: "https://github.com/mitre/vulcan/blob/master/CONTRIBUTING.md" },
            { text: "Code of Conduct", link: "/CODE_OF_CONDUCT.md" },
          ],
        },
      ],
      "/api/": [
        {
          text: "API Guide",
          items: [
            { text: "Overview", link: "/api/overview" },
            { text: "Authentication", link: "/api/authentication" },
            { text: "Errors", link: "/api/errors" },
          ],
        },
        ...useSidebar({
          spec,
          linkPrefix: "/api/operations/",
          tagLinkPrefix: "/api/tags/",
        }).generateSidebarGroups(),
      ],
      "/security/": [
        {
          text: "Security",
          items: [
            { text: "Security Policy", link: "/SECURITY.md" },
            { text: "Compliance Guide", link: "/security/compliance" },
            { text: "ASD SRG Responses", link: "/security/security-controls" },
          ],
        },
      ],
      "/": [
        {
          text: "Overview",
          items: [
            { text: "About Vulcan", link: "/about" },
            { text: "Media Kit & Branding", link: "/about/media-kit" },
            { text: "Quick Start", link: "/getting-started/quick-start" },
          ],
        },
        {
          text: "Documentation",
          items: [
            { text: "Getting Started", link: "/getting-started/quick-start" },
            { text: "Deployment", link: "/deployment/docker" },
            { text: "Development", link: "/development/setup" },
            { text: "API Reference", link: "/api/overview" },
            { text: "Security", link: "/security/compliance" },
          ],
        },
        {
          text: "Project Info",
          items: [
            { text: "README", link: "https://github.com/mitre/vulcan/blob/master/README.md" },
            { text: "Changelog", link: "/CHANGELOG.md" },
            { text: "Roadmap", link: "/ROADMAP.md" },
            { text: "License", link: "/LICENSE.md" },
            { text: "Notice", link: "/NOTICE.md" },
            { text: "Contributing", link: "/CONTRIBUTING.md" },
            { text: "Security Policy", link: "/SECURITY.md" },
          ],
        },
      ],
      };
    })(),

    // Social links — outbound, so only where the internet is (target table).
    ...(target.outboundChrome
      ? {
          socialLinks: [
            { icon: "github", link: "https://github.com/mitre/vulcan" },
            { icon: "docker", link: "https://hub.docker.com/r/mitre/vulcan" },
          ],
        }
      : {}),

    // Search
    search: {
      provider: "local",
    },

    // Edit link — outbound, per-page GitHub footer; same target gate.
    ...(target.outboundChrome
      ? {
          editLink: {
            pattern: "https://github.com/mitre/vulcan/edit/master/docs/:path",
            text: "Edit this page on GitHub",
          },
        }
      : {}),

    // Footer
    footer: {
      message: "Part of the MITRE Security Automation Framework (SAF)",
      copyright: "Copyright © 2025 MITRE Corporation",
    },

    // Page navigation
    docFooter: {
      prev: "Previous",
      next: "Next",
    },

    // Outline
    outline: {
      level: [2, 3],
      label: "On this page",
    },
  },

  // Vite configuration
  vite: {
    resolve: {
      preserveSymlinks: true
    },
    plugins: [
      ViteImageOptimizer({
        svg: {
          multipass: true,
          plugins: [
            {
              name: "preset-default",
              params: {
                overrides: {
                  cleanupIds: {
                    minify: true,
                  },
                  convertPathData: {
                    floatPrecision: 2,
                  },
                },
              },
            },
            {
              name: "removeViewBox",
              active: false,
            },
            {
              name: "removeTitle",
              active: false,
            },
            {
              name: "removeDesc",
              active: false,
            },
          ],
        },
      }),
    ],
  },

  // Markdown configuration
  markdown: {
    lineNumbers: true,
    toc: { level: [2, 3] },

    // Custom containers
    container: {
      tipLabel: "TIP",
      warningLabel: "WARNING",
      dangerLabel: "DANGER",
      infoLabel: "INFO",
      detailsLabel: "Details",
    },

    // Custom markdown-it configuration for Mermaid
    config: (md) => {
      const fence = md.renderer.rules.fence;
      md.renderer.rules.fence = (tokens, idx, options, env, renderer) => {
        const token = tokens[idx];
        if (token.info === "mermaid") {
          const code = token.content.trim();
          return `<Mermaid :graph="\`${code.replace(/`/g, "\\`")}\`" />`;
        }
        return fence(tokens, idx, options, env, renderer);
      };
    },
  },

  // Ignore dead links for localhost URLs
  ignoreDeadLinks: [
    // Ignore localhost URLs
    /^https?:\/\/localhost/,
    // Binary attachments served from public/ — VitePress can't resolve non-page files
    /\.docx$/,
  ],
});
