---
layout: home

hero:
  name: "Vulcan"
  text: "STIG-Ready Security Guidance"
  tagline: Streamline the creation of STIG documentation and InSpec validation profiles
  image:
    src: /logo.svg
    alt: Vulcan
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started/quick-start
    - theme: alt
      text: Try Production
      link: https://mitre-vulcan-prod.herokuapp.com/users/sign_in
    - theme: alt
      text: View on GitHub
      link: https://github.com/mitre/vulcan

features:
  - icon: 📋
    title: STIG Process Modeling
    details: Manage the complete workflow between vendors and sponsors for STIG creation
  - icon: 🔍
    title: InSpec Integration
    details: Write and test validation code locally or across SSH, AWS, and Docker targets
  - icon: 📊
    title: Control Management
    details: Track control status, revision history, and relationships between requirements
  - icon: 👥
    title: Collaborative Authoring
    details: Multiple authors can work on control sets with built-in review workflows
  - icon: 🔗
    title: Cross-Reference STIGs
    details: Look up related controls across all published STIGs for consistency
  - icon: 🔐
    title: Enterprise Security
    details: Database encryption, flexible authentication with OIDC, LDAP, and GitHub
---

## Quick Start

### Quick Test with Docker

```bash
docker pull mitre/vulcan:latest
docker run -p 3000:3000 mitre/vulcan:latest
```

### Full Setup with Docker Compose

```bash
# Clone the repository
git clone https://github.com/mitre/vulcan.git
cd vulcan

# Generate secure configuration
./.github/setup-docker-secrets.sh

# Start the application stack
docker-compose -f .github/docker-compose.yml up
```

## Latest Release

::: info Current Version
**v2.2.1** - Released August 16, 2025

Security patch release addressing critical vulnerability fixes.
[View Release Notes →](/release-notes/v2.2.1)
:::

## Why Vulcan?

Vulcan bridges the gap between security requirements and practical implementation, enabling organizations to:

- **Accelerate STIG Development**: Reduce time from months to weeks
- **Ensure Consistency**: Maintain alignment with DISA standards
- **Automate Validation**: Generate InSpec profiles alongside documentation
- **Collaborate Effectively**: Built-in workflows for multi-team environments
- **Track Compliance**: Full audit trail and revision history

## Technology Stack

<div class="tech-stack">
  <div class="tech-section">
    <h3>Backend</h3>
    <ul>
      <li>Ruby 3.3.9 with Rails 8.0.2.1</li>
      <li>PostgreSQL 12+</li>
      <li>Redis for caching</li>
    </ul>
  </div>
  <div class="tech-section">
    <h3>Frontend</h3>
    <ul>
      <li>Vue 2.6.11</li>
      <li>Bootstrap 4.4.1</li>
      <li>Turbolinks 5.2.0</li>
    </ul>
  </div>
  <div class="tech-section">
    <h3>DevOps</h3>
    <ul>
      <li>Docker optimized images</li>
      <li>GitHub Actions CI/CD</li>
      <li>Kubernetes ready</li>
    </ul>
  </div>
</div>

## Part of MITRE SAF

Vulcan is a core component of the [MITRE Security Automation Framework (SAF)](https://saf.mitre.org/), a comprehensive suite of tools designed to automate security validation and compliance checking.

<div class="saf-ecosystem">
  <a href="https://www.inspec.io/" class="saf-tool">
    <h4>InSpec</h4>
    <p>Compliance automation framework</p>
  </a>
  <a href="https://github.com/mitre/heimdall2" class="saf-tool">
    <h4>Heimdall</h4>
    <p>Security results visualization</p>
  </a>
  <a href="https://github.com/mitre/saf-cli" class="saf-tool">
    <h4>SAF CLI</h4>
    <p>Command-line security tools</p>
  </a>
</div>

## Get Involved

<div class="action-cards">
  <div class="action-card">
    <h3>📚 Documentation</h3>
    <p>Comprehensive guides for users and developers</p>
    <a href="/getting-started/installation">Read the Docs →</a>
  </div>
  <div class="action-card">
    <h3>🤝 Contributing</h3>
    <p>Help improve Vulcan with code, docs, or feedback</p>
    <a href="https://github.com/mitre/vulcan/blob/master/CONTRIBUTING.md">Contribution Guide →</a>
  </div>
  <div class="action-card">
    <h3>💬 Community</h3>
    <p>Get help and discuss with other users</p>
    <a href="https://github.com/mitre/vulcan/discussions">Join Discussions →</a>
  </div>
</div>

<style>
.tech-stack {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 2rem;
  margin: 2rem 0;
}

.tech-section h3 {
  color: var(--vp-c-brand);
  margin-bottom: 0.5rem;
}

.tech-section ul {
  list-style: none;
  padding: 0;
}

.tech-section li {
  padding: 0.25rem 0;
}

.saf-ecosystem {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
  margin: 2rem 0;
}

.saf-tool {
  padding: 1.5rem;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  text-decoration: none;
  transition: all 0.3s;
}

.saf-tool:hover {
  border-color: var(--vp-c-brand);
  transform: translateY(-2px);
}

.saf-tool h4 {
  color: var(--vp-c-brand);
  margin: 0 0 0.5rem 0;
}

.saf-tool p {
  color: var(--vp-c-text-2);
  margin: 0;
}

.action-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1.5rem;
  margin: 2rem 0;
}

.action-card {
  padding: 1.5rem;
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
}

.action-card h3 {
  margin: 0 0 0.5rem 0;
}

.action-card p {
  color: var(--vp-c-text-2);
  margin: 0.5rem 0 1rem 0;
}

.action-card a {
  color: var(--vp-c-brand);
  font-weight: 500;
}
</style>