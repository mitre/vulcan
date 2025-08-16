import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: 'Vulcan',
  description: 'Security Technical Implementation Guide (STIG) creation and validation platform',
  base: '/vulcan/',

  // Clean URLs without .html extension
  cleanUrls: true,

  // Last updated time
  lastUpdated: true,

  // Head tags
  head: [
    ['link', { rel: 'icon', href: '/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#3eaf7c' }],
  ],

  // Theme configuration
  themeConfig: {
    // Logo in nav bar
    logo: '/logo.png',

    // Navigation bar
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Getting Started', link: '/getting-started/quick-start' },
      { text: 'User Guide', link: '/user-guide/overview' },
      {
        text: 'Development',
        items: [
          { text: 'Setup', link: '/development/setup' },
          { text: 'Architecture', link: '/development/architecture' },
          { text: 'Testing', link: '/development/testing' },
          { text: 'Contributing', link: '/CONTRIBUTING' }
        ]
      },
      { text: 'API', link: '/api/overview' },
      {
        text: 'v2.2.1',
        items: [
          { text: 'Changelog', link: '/CHANGELOG' },
          { text: 'Release Notes', link: '/release-notes/v2.2.1' },
          { text: 'v2.2.0', link: '/release-notes/v2.2.0' }
        ]
      }
    ],

    // Sidebar navigation
    sidebar: {
      '/getting-started/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Quick Start', link: '/getting-started/quick-start' },
            { text: 'Installation', link: '/getting-started/installation' },
            { text: 'Configuration', link: '/getting-started/configuration' },
            { text: 'Environment Variables', link: '/getting-started/environment-variables' }
          ]
        }
      ],
      '/deployment/': [
        {
          text: 'Deployment Options',
          items: [
            { text: 'Docker', link: '/deployment/docker' },
            { text: 'Bare Metal', link: '/deployment/bare-metal' },
            { text: 'Heroku', link: '/deployment/heroku' },
            { text: 'Kubernetes', link: '/deployment/kubernetes' }
          ]
        },
        {
          text: 'Authentication Setup',
          items: [
            { text: 'OIDC/OKTA', link: '/deployment/auth/oidc-okta' },
            { text: 'LDAP', link: '/deployment/auth/ldap' },
            { text: 'GitHub OAuth', link: '/deployment/auth/github' }
          ]
        }
      ],
      '/development/': [
        {
          text: 'Development',
          items: [
            { text: 'Development Setup', link: '/development/setup' },
            { text: 'Architecture', link: '/development/architecture' },
            { text: 'Testing', link: '/development/testing' },
            { text: 'Release Process', link: '/development/release-process' },
            { text: 'Vue 3 Migration', link: '/development/vue3-migration' }
          ]
        },
        {
          text: 'Contributing',
          items: [
            { text: 'Contributing Guide', link: '/CONTRIBUTING' },
            { text: 'Code of Conduct', link: '/CODE_OF_CONDUCT' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/overview' },
            { text: 'Authentication', link: '/api/authentication' },
            { text: 'Endpoints', link: '/api/endpoints' }
          ]
        }
      ],
      '/security/': [
        {
          text: 'Security',
          items: [
            { text: 'Security Policy', link: '/SECURITY' },
            { text: 'Compliance & Controls', link: '/security/compliance' },
            { text: 'Security Controls', link: '/security/security-controls' },
            { text: 'Data Encryption', link: '/security/data-encryption' }
          ]
        }
      ],
      '/': [
        {
          text: 'Overview',
          items: [
            { text: 'About Vulcan', link: '/about' },
            { text: 'Quick Start', link: '/getting-started/quick-start' },
            { text: 'User Guide', link: '/user-guide/overview' }
          ]
        },
        {
          text: 'Deployment',
          collapsed: true,
          items: [
            { text: 'Docker', link: '/deployment/docker' },
            { text: 'Kubernetes', link: '/deployment/kubernetes' },
            { text: 'Heroku', link: '/deployment/heroku' },
            { text: 'Bare Metal', link: '/deployment/bare-metal' }
          ]
        },
        {
          text: 'Project Info',
          items: [
            { text: 'Changelog', link: '/CHANGELOG' },
            { text: 'Roadmap', link: '/ROADMAP' },
            { text: 'License', link: '/LICENSE' },
            { text: 'Notice', link: '/NOTICE' }
          ]
        }
      ]
    },

    // Social links
    socialLinks: [
      { icon: 'github', link: 'https://github.com/mitre/vulcan' },
      { icon: 'docker', link: 'https://hub.docker.com/r/mitre/vulcan' }
    ],

    // Search
    search: {
      provider: 'local'
    },

    // Edit link
    editLink: {
      pattern: 'https://github.com/mitre/vulcan/edit/master/docs/:path',
      text: 'Edit this page on GitHub'
    },

    // Footer
    footer: {
      message: 'Part of the MITRE Security Automation Framework (SAF)',
      copyright: 'Copyright © 2025 MITRE Corporation'
    },

    // Page navigation
    docFooter: {
      prev: 'Previous',
      next: 'Next'
    },

    // Outline
    outline: {
      level: [2, 3],
      label: 'On this page'
    }
  },

  // Markdown configuration
  markdown: {
    lineNumbers: true,
    toc: { level: [2, 3] },

    // Custom containers
    container: {
      tipLabel: 'TIP',
      warningLabel: 'WARNING',
      dangerLabel: 'DANGER',
      infoLabel: 'INFO',
      detailsLabel: 'Details'
    }
  },

  // Build configuration
  vite: {
    // Vite options
  }
})