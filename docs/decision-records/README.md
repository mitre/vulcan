# Decision Records

This directory contains Architectural Decision Records (ADRs) and technical decision documentation for the Vulcan project.

## Index

### Infrastructure Decisions
- [configuration-system-modernization.md](configuration-system-modernization.md) - settingslogic → rails-settings-cached migration
- [webpacker-to-jsbundling-migration.md](webpacker-to-jsbundling-migration.md) - Asset pipeline modernization decision

### Architecture Decisions
- [modernization-strategy.md](modernization-strategy.md) - Overall platform modernization approach

## Format

Each decision record should include:
- **Status**: Proposed, Accepted, Deprecated, Superseded
- **Context**: The situation driving the need for this decision
- **Decision**: The change we're proposing or have agreed to implement
- **Consequences**: What becomes easier or more difficult to do

## Related Documentation
- [Project Guides](../guides/) - Implementation guides and tutorials
- [Architecture Overview](../architecture/) - High-level system architecture
- [Vulcan Modernization Roadmap](../../Vulcan-Modernization-Roadmap.md) - Strategic planning
- [EPIC Issues](https://github.com/mitre/vulcan/issues?q=label%3Aepic) - High-level tracking