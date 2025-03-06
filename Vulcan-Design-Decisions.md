# Vulcan Design Decisions

This document captures key design decisions made during the modernization of the Vulcan application. It serves as a reference for understanding the reasoning behind architectural and technology choices.

## Frontend Framework and Libraries

### Vue 3 + bootstrap-vue-3

**Decision**: When upgrading from Vue 2 to Vue 3, we will use bootstrap-vue-3 as our component library.

**Context**:
- The application currently uses Vue 2 with bootstrap-vue
- We need to upgrade to Vue 3 which is not compatible with bootstrap-vue
- We evaluated multiple options including bootstrap-vue-3 and UseBootstrap.org

**Rationale**:
- Bootstrap-vue-3 provides near-complete coverage of the original bootstrap-vue components
- It maintains a very similar API, minimizing migration effort and potential bugs
- Our application heavily relies on specialized components (tables, forms, modals) that are fully implemented in bootstrap-vue-3
- The consistent naming conventions will make incremental migration more feasible
- It has stronger community support (3.2k+ GitHub stars) and active development

**Alternatives Considered**:
- **UseBootstrap.org**: While modern and lighter weight, it has a more limited component set and would require significant refactoring of our existing components
- **Nuxt UI**: Modern and comprehensive, but would require a major architectural shift to Nuxt 3
- **Vuetify**: Full-featured but uses Material Design instead of Bootstrap, requiring complete UI redesign
- **PrimeVue**: Comprehensive but significantly different API and design language

**Implementation Guidelines**:
- Create an adapter layer for any missing components
- Migrate one component type at a time, starting with simpler ones
- Update tests for each component after migration

## Build Systems

### jsbundling-rails with esbuild

**Decision**: Replace Webpacker with jsbundling-rails using esbuild as the bundler.

**Context**:
- Webpacker is no longer maintained
- Need a modern, supported solution for JavaScript bundling in Rails
- Current asset organization is complex with multiple entry points

**Rationale**:
- esbuild is significantly faster than webpack
- The jsbundling-rails + Propshaft combination is recommended by the Rails team
- Simpler configuration compared to Webpacker
- Maintains compatibility with existing JavaScript ecosystem
- Does not require major architectural changes

**Alternatives Considered**:
- **importmaps**: Not suitable for our complex application with many dependencies
- **rollup**: More complex configuration than esbuild for our needs
- **Vite**: Would require more changes to our build process

**Implementation Guidelines**:
- Migrate entry points one at a time
- Maintain consistent naming conventions
- Ensure all assets are properly fingerprinted
- Keep temporary backward compatibility where needed

## API and Data Validation

### Schema Validation Approach

**Decision**: To be determined during Phase 1, with consideration given to Zod-like approach.

**Context**:
- Current API lacks consistent validation
- Type safety would improve reliability
- Frontend and backend validation is inconsistent

**Options Under Consideration**:
- Ruby-side validation with strong_parameters and custom validators
- JSON Schema validation at API boundaries
- Zod-like approach for schema definition and validation
- GraphQL with strong typing

**Decision Points**:
- Whether to share schema definitions between frontend and backend
- Performance implications of validation approaches
- Developer experience and learning curve
- Integration with existing Rails validations

## State Management

**Decision**: To be determined during Phase 3, with Pinia as the recommended option.

**Context**:
- Current state management is ad-hoc and prop-based
- Need for more consistent, maintainable approach with Vue 3

**Options Under Consideration**:
- Pinia (recommended replacement for Vuex in Vue 3)
- Composition API with provide/inject
- Simple reactive stores
- Custom event bus

**Decision Points**:
- Complexity vs. simplicity tradeoffs
- Component reusability requirements
- Performance considerations
- Developer experience

## Database Optimization Strategy

**Decision**: To be determined during Phase 1 after audit.

**Context**:
- Current database design may have performance bottlenecks
- Need to ensure scalability for larger datasets
- Potential optimization opportunities through indexing, denormalization, etc.

**Options Under Consideration**:
- Improved indexing strategy
- Denormalization for read-heavy operations
- Query optimization
- Caching strategies (Redis, in-memory, etc.)
- Potential schema changes

**Decision Points**:
- Performance vs. complexity tradeoffs
- Specific bottlenecks identified in audit
- Migration complexity for any schema changes
- Data integrity considerations

## Testing Strategy

**Decision**: Implement comprehensive testing at both backend and frontend levels with specific frameworks to be determined.

**Context**:
- Current test coverage has gaps
- Frontend testing particularly needs enhancement
- Need consistent approach across codebase

**Options Under Consideration**:
- RSpec for Rails (currently in use)
- Vue Test Utils for component testing
- Playwright or Cypress for end-to-end testing
- Storybook for component documentation and visual testing

**Decision Points**:
- Coverage targets for each type of testing
- Integration with CI/CD pipeline
- Balance between unit, integration, and E2E tests
- Developer workflow and ease of writing tests

## Structured Document and Code Collaboration

### Collaborative Workflow for STIG Development

**Decision**: To be evaluated during Phase 3, with a comprehensive approach combining:
1. ActionCable for presence and notifications
2. Robust versioning for document history and collaboration
3. Code-specific collaborative editing for InSpec and Ansible content

**Context**:
- Vulcan manages the lifecycle of security guidance documents (STIGs derived from SRGs)
- The application supports multiple interconnected workflows with different collaboration needs:
  - Structured form-based editing of security requirements (field updates)
  - InSpec code development for automated testing (Ruby DSL, syntax-aware editing)
  - Planned Ansible task creation for implementation automation (YAML with real-time editing)
  - Git-flow style peer review process
  - Version comparison and diff functionality
  - Cross-reference of related requirements with the same SRG ID across projects
- Multiple users may need to collaboratively edit code in real-time, similar to multi-cursor editing
- Both document structure and code content require collaboration capabilities
- History tracking and audit capabilities are essential

**Options Under Consideration**:

1. **Yjs-Powered Code Collaboration + Structured Document Management**
   - Uses Yjs CRDT library for real-time collaborative code editing
   - ActionCable as transport layer for Yjs updates
   - Monaco Editor integration with Yjs binding for InSpec/Ansible
   - Support for multi-cursor editing in code sections
   - Awareness of who is editing which code blocks
   - Leverages structured document storage in PostgreSQL for form data
   - Implements optimistic UI with server-side conflict resolution for form fields
   - Enhanced diff visualization for comparing versions
   - Supports the git-flow style review process

2. **GraphQL-Based Hybrid Collaboration System**
   - Schema that mirrors both structured data and code content
   - Subscriptions for real-time updates to specific document sections and code
   - Strong typing and validation for security requirements
   - Monaco Editor with GraphQL subscription for code updates
   - Supports collaborative code editing through GraphQL updates
   - Facilitates cross-project knowledge sharing
   - Enables granular permissions and content visibility
   - Supports complex queries for related requirements

3. **Firepad-Inspired Code Collaboration**
   - Based on operational transforms for collaborative editing
   - Monaco Editor integration with collaborative features
   - Real-time multi-user editing of code sections
   - Syntax highlighting and validation for InSpec and Ansible
   - Traditional form-based collaboration for structured data
   - Integrated chat and annotation system for code review
   - User presence and cursor position sharing

4. **Modular Collaboration by Content Type**
   - Different collaboration strategies optimized for different content types:
     - Form-based fields: Traditional Rails with optimistic UI
     - Code sections: Collaborative text editing with Yjs or similar
     - Review workflow: Git-inspired approval model
   - Unified data model with specialized collaboration components
   - Tailored editing experience for each content type
   - Seamless transitions between different collaboration modes

5. **Monaco + Custom WebSocket Protocol**
   - Custom WebSocket protocol for efficient code updates
   - Monaco Editor with real-time collaboration extensions
   - Specialized for InSpec and Ansible syntax
   - Optimized for low-latency collaborative editing
   - Language-specific features like autocompletion and validation
   - Conflict resolution strategies designed for code
   - Integration with form-based document editing

**Decision Points**:
- Real-time collaboration requirements for code vs. form fields
- Conflict resolution strategies appropriate for code editing
- Performance considerations for collaborative editing
- Monaco Editor vs. alternative code editors for InSpec/Ansible
- User experience for showing multiple cursors and changes
- Offline capabilities and synchronization strategies
- Integration between code collaboration and document collaboration
- Balance between collaborative editing and review workflow

## Ansible Automation Integration

### Approach for Generating Ansible Tasks from Requirements

**Decision**: To be evaluated during Phase 1, with a Jinja2 template-based approach similar to Benchmark-Generator as the recommended implementation.

**Context**:
- Vulcan currently supports InSpec code generation for automated testing
- There's a need to extend this to include Ansible task generation for automated implementation
- The Benchmark-Generator project provides a reference implementation for XCCDF to Ansible conversion
- Both STIG requirements and resulting Ansible tasks should maintain traceability
- Template-based generation allows for consistent structure while accommodating different requirement types

**Options Under Consideration**:

1. **Jinja2 Template System with Rule Categorization**
   - Use a templating approach similar to Benchmark-Generator
   - Categorize requirements by implementation type (file, service, package, etc.)
   - Generate skeleton tasks with appropriate tags and metadata
   - Maintain rule ID and metadata in task comments for traceability
   - Offer "audit" and "remediation" task pairs for each requirement

2. **AI-Assisted Task Generation with Human Review**
   - Use AI to analyze requirement text and suggest Ansible task implementations
   - Present suggestions for human review before finalization
   - Train on existing implementation patterns for continuous improvement
   - Maintain a library of approved implementation patterns
   - Leverage requirement categorization to improve suggestion quality

3. **Pattern Library with Parameterization**
   - Build a library of common implementation patterns for different requirement types
   - Allow users to select and parameterize patterns for specific requirements
   - Integrate with existing rule data to pre-populate fields
   - Support custom extensions for organization-specific implementations
   - Version control pattern library alongside application code

4. **DSL-to-Ansible Approach**
   - Create a domain-specific language for describing security implementations
   - Automatically convert DSL to Ansible tasks
   - Potentially share the DSL between InSpec and Ansible generation
   - Provide higher-level abstractions for common security patterns
   - Allow for extension with custom modules

5. **YAML Builder Interface**
   - Provide a structured interface for building Ansible tasks
   - Allow drag-and-drop assembly of task components
   - Validate task structure against Ansible best practices
   - Generate properly formatted YAML with appropriate indentation
   - Include built-in variable management

**Decision Points**:
- Level of automation vs. human input required
- Integration with InSpec code generation workflow
- Template maintenance and versioning strategy
- Handling of different OS and application types
- Testing approach for generated Ansible tasks
- Export format and structure for playbooks

## Advanced Feature Integration

### Test Runner for InSpec and Ansible

**Decision**: To be evaluated during Phase 3, with a containerized test environment as the recommended approach.

**Context**:
- Users need to validate InSpec and Ansible code as they write it
- Current workflow requires deploying to external systems for testing
- Immediate feedback would significantly improve the development cycle
- Testing should be available directly in the Vulcan interface
- Both InSpec tests and Ansible remediation should be testable

**Options Under Consideration**:

1. **Containerized Test Environments**
   - Deploy ephemeral containers for testing
   - Pre-configured containers for different target systems (RHEL, Windows, etc.)
   - Real-time output streaming to the UI
   - Integration with Monaco Editor for error highlighting
   - Support for both InSpec and Ansible execution
   - Secure isolation between test environments

2. **Remote Agent Architecture**
   - Lightweight agents deployed on test targets
   - API for InSpec and Ansible execution
   - Results streamed back to Vulcan UI
   - Support for persistent test environments
   - Credential management for target systems
   - Dashboard for agent health and status

3. **Integration with CI/CD Platforms**
   - Leverage existing CI/CD infrastructure (GitHub Actions, Jenkins, etc.)
   - Define test jobs that run against target environments
   - Badge-based feedback in the UI
   - Log streaming from CI/CD systems
   - History of test runs with detailed results
   - Scheduling options for resource-intensive tests

4. **Local Browser-Based Testing**
   - WebAssembly-powered testing environment
   - Simulated OS environment in the browser
   - Limited but immediate feedback
   - No server-side resources required
   - Supplement with server-side testing for complex scenarios
   - Fast iteration cycle for basic validation

5. **Hybrid Approach with Test Levels**
   - Simple linting and validation in the browser (instant)
   - Mid-level testing in ephemeral containers (fast)
   - Full environment testing via agents (comprehensive)
   - Appropriate feedback for each test level
   - Progressive disclosure of test results
   - Resource allocation based on test importance

**Decision Points**:
- Infrastructure requirements and management
- Security considerations for executing user code
- Performance impact on the application
- Support for various target operating systems
- Integration with the development workflow
- Feedback mechanisms and result presentation
- Resource allocation and scaling strategy

### AI-Assisted Content Creation

**Decision**: To be evaluated during Phase 2, with a phased approach starting with requirement drafting assistance.

**Context**:
- Writing security requirements, InSpec tests, and Ansible tasks requires specialized knowledge
- Published STIGs in the database provide valuable examples
- AI could assist users in drafting and improving content
- Different content types (requirements, InSpec, Ansible) need specialized assistance
- Reference materials can inform AI suggestions

**Options Under Consideration**:

1. **Multi-Stage AI Assistant**
   - Progressive AI assistance across the workflow:
     - Requirement drafting based on SRG and similar STIGs
     - InSpec test generation from requirements
     - Ansible task creation from requirements and InSpec
   - Learning from existing content in the database
   - Contextual suggestions based on current work
   - Integration with Monaco Editor for code assistance
   - Reference linking to similar implementations

2. **Large Language Model Integration**
   - Integration with models like GPT or Claude
   - Fine-tuning on security requirement corpus
   - Specialized prompts for different content types
   - Split-screen suggestion and editing interface
   - Confidence scoring for suggestions
   - Reference citation for suggested content

3. **Pattern-Based AI Assistance**
   - Library of patterns extracted from existing STIGs
   - ML-based pattern matching for new content
   - Suggestion of appropriate patterns based on context
   - Parameter filling assistance
   - Built-in quality checking and improvement suggestions
   - Continuous learning from user selections

4. **Collaborative Filtering Approach**
   - "Others implementing this requirement used..." suggestions
   - Popularity-based recommendations
   - Co-occurrence analysis of implementation patterns
   - Community-driven content improvement
   - Rating system for implementation quality
   - Personalized suggestions based on team history

5. **Knowledge Graph-Powered Assistant**
   - Semantic understanding of requirements and implementations
   - Relationship mapping between requirements and code
   - Contextual suggestions based on requirement relationships
   - Cross-reference visualization
   - Impact analysis for changes
   - Reasoning-based suggestions with explanations

**Decision Points**:
- AI model selection and hosting
- Integration with existing workflow
- User experience for suggestion presentation
- Balance between automation and human judgment
- Learning mechanisms from user feedback
- Privacy and security considerations
- Performance impact on the application

## Maintenance and Updates

This document will be updated as significant design decisions are made throughout the modernization process. Each entry should include:

- The specific decision made
- Context that led to the decision
- Rationale for the choice
- Alternatives considered
- Implementation guidelines or constraints

All team members are encouraged to reference and contribute to this document when making architectural or technology decisions.