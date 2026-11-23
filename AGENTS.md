# AGENTS.md

Instructions for AI coding agents in this repository are in [CLAUDE.md](CLAUDE.md); read it first. The sections below repeat two of its points for agents that read only AGENTS.md.

## SonarCloud

Use the official `sonar` CLI (Homebrew cask `sonarqube-cli`). Run `sonar auth login` once in a terminal; it reads `sonar-project.properties`.

```bash
sonar qg status --pull-request <n>             # Quality gate for a PR (--all, --top N)
sonar list issues --pull-request <n>           # Open issues on a PR (--new-code, --file <path>, --format json)
sonar api get '/api/rules/show?key=<rule>&organization=mitre'  # A rule's "how to fix" text
```

## Unknowns and External Tools

- Two failed attempts at the same question is the limit, however the method changes (an API, then a web page, then a source repository is three attempts at one question). After the second, stop and ask the maintainer, with what was tried.
- Before working around a tool (anonymous API calls, scraped pages, hand-written parsers), check for the vendor's official CLI. For SonarCloud that is `sonar` above; anonymous Web API calls do not return rule text.
