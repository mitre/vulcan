import { defineConfig } from "vitepress";
import { ViteImageOptimizer } from "vite-plugin-image-optimizer";

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Vulcan",
  description: "Security Technical Implementation Guide (STIG) creation and validation platform",
  // Use / for GitHub Pages with custom domain (vulcan.mitre.org), /vulcan/ for local dev
  base: process.env.GITHUB_DEPLOY === "true" ? "/" : "/vulcan/",

  // Clean URLs without .html extension
  cleanUrls: true,

  // Last updated time
  lastUpdated: true,

  // Head tags
  head: [
    ["link", { rel: "icon", type: "image/svg+xml", href: "/favicon.svg" }],
    ["link", { rel: "alternate icon", href: "/favicon.ico" }],
    ["link", { rel: "apple-touch-icon", href: "/app-icon.svg" }],
    ["meta", { name: "theme-color", content: "#3498db" }],
  ],

  // Theme configuration
  themeConfig: {
    // Logo in nav bar
    logo: "/logo.png",

    // Navigation bar
    nav: [
      { text: "Home", link: "/" },
      { text: "Getting Started", link: "/getting-started/quick-start" },
      { text: "User Guide", link: "https://mitre.github.io/saf-training/courses/guidance/" },
      {
        text: "Deployment",
        items: [
          { text: "Docker", link: "/deployment/docker" },
          { text: "Kubernetes", link: "/deployment/kubernetes" },
          { text: "Heroku", link: "/deployment/heroku" },
          { text: "Bare Metal", link: "/deployment/bare-metal" },
          { text: "Health Monitoring", link: "/deployment/monitoring" },
        ],
      },
      {
        text: "Authentication",
        items: [
          { text: "OIDC/OKTA", link: "/deployment/auth/oidc-okta" },
          { text: "LDAP", link: "/deployment/auth/ldap" },
          { text: "GitHub OAuth", link: "/deployment/auth/github" },
        ],
      },
      {
        text: "Development",
        items: [
          { text: "Setup", link: "/development/setup" },
          { text: "Documentation", link: "/development/documentation" },
          { text: "Architecture", link: "/development/architecture" },
          { text: "Testing", link: "/development/testing" },
          { text: "Release Process", link: "/development/release-process" },
          { text: "Contributing", link: "/CONTRIBUTING.md" },
        ],
      },
      {
        text: "API",
        items: [
          { text: "Overview", link: "/api/overview" },
          { text: "Authentication", link: "/api/authentication" },
          { text: "Endpoints", link: "/api/endpoints" },
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
      {
        text: "Project",
        items: [
          { text: "About", link: "/README.md" },
          { text: "Changelog", link: "/CHANGELOG.md" },
          { text: "Roadmap", link: "/ROADMAP.md" },
          { text: "Contributing", link: "/CONTRIBUTING.md" },
          { text: "Code of Conduct", link: "/CODE_OF_CONDUCT.md" },
          { text: "License", link: "/LICENSE.md" },
          { text: "Notice", link: "/NOTICE.md" },
          { text: "Security Policy", link: "/SECURITY.md" },
        ],
      },
      {
        text: "v2.2.1",
        items: [
          { text: "Release Notes", link: "/release-notes/v2.2.1" },
          { text: "v2.2.0", link: "/release-notes/v2.2.0" },
          { text: "All Releases", link: "/release-notes/" },
        ],
      },
    ],

    // Sidebar navigation
    sidebar: {
      "/getting-started/": [
        {
          text: "Getting Started",
          items: [
            { text: "Quick Start", link: "/getting-started/quick-start" },
            { text: "Installation", link: "/getting-started/installation" },
            { text: "Configuration", link: "/getting-started/configuration" },
            { text: "Environment Variables", link: "/getting-started/environment-variables" },
          ],
        },
      ],
      "/deployment/": [
        {
          text: "Deployment Options",
          items: [
            { text: "Docker", link: "/deployment/docker" },
            { text: "Bare Metal", link: "/deployment/bare-metal" },
            { text: "Heroku", link: "/deployment/heroku" },
            { text: "Kubernetes", link: "/deployment/kubernetes" },
            { text: "Health Monitoring", link: "/deployment/monitoring" },
          ],
        },
        {
          text: "Authentication Setup",
          items: [
            { text: "OIDC/OKTA", link: "/deployment/auth/oidc-okta" },
            { text: "LDAP", link: "/deployment/auth/ldap" },
            { text: "GitHub OAuth", link: "/deployment/auth/github" },
          ],
        },
      ],
      "/development/": [
        {
          text: "Development",
          items: [
            { text: "Development Setup", link: "/development/setup" },
            { text: "Documentation Guide", link: "/development/documentation" },
            { text: "Architecture", link: "/development/architecture" },
            { text: "Testing", link: "/development/testing" },
            { text: "Release Process", link: "/development/release-process" },
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
          text: "API Reference",
          items: [
            { text: "Overview", link: "/api/overview" },
            { text: "Authentication", link: "/api/authentication" },
            { text: "Endpoints", link: "/api/endpoints" },
          ],
        },
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
            { text: "About Vulcan", link: "https://github.com/mitre/vulcan" },
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
    },

    // Social links
    socialLinks: [
      { icon: "github", link: "https://github.com/mitre/vulcan" },
      { icon: "docker", link: "https://hub.docker.com/r/mitre/vulcan" },
    ],

    // Search
    search: {
      provider: "local",
    },

    // Edit link
    editLink: {
      pattern: "https://github.com/mitre/vulcan/edit/master/docs/:path",
      text: "Edit this page on GitHub",
    },

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
                  // Clean up IDs
                  cleanupIds: {
                    minify: true,
                  },
                  // Optimize paths
                  convertPathData: {
                    floatPrecision: 2,
                  },
                },
              },
            },
            // Keep viewBox for scaling
            {
              name: "removeViewBox",
              active: false,
            },
            // Keep title and desc for accessibility
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
  ],
});
