# Architecture Documentation

This directory contains high-level system architecture documentation for the Vulcan platform.

## Index

### System Overview
- [vulcan-system-architecture.md](vulcan-system-architecture.md) - Overall system design and components
- [data-model.md](data-model.md) - Database schema and relationships
- [security-architecture.md](security-architecture.md) - Authentication, authorization, and security controls

### Integration Architecture
- [authentication-flow.md](authentication-flow.md) - OIDC, LDAP, and local authentication
- [asset-pipeline.md](asset-pipeline.md) - JavaScript and CSS build system
- [configuration-management.md](configuration-management.md) - Environment and runtime configuration

### Deployment Architecture
- [infrastructure-overview.md](infrastructure-overview.md) - Deployment targets and requirements
- [scalability-design.md](scalability-design.md) - Performance and scaling considerations

## Format

Each architecture document should include:
- **Purpose**: What system or component this describes
- **Context**: How it fits into the overall system
- **Components**: Key parts and their responsibilities
- **Interactions**: How components communicate
- **Constraints**: Technical limitations and decisions

## Related Documentation
- [Decision Records](../decision-records/) - Why architectural decisions were made
- [Implementation Guides](../guides/) - How to work with these systems
- [Vulcan Modernization Roadmap](../../Vulcan-Modernization-Roadmap.md) - Evolution strategy