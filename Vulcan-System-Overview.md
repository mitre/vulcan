# Vulcan System Overview

## Purpose and Core Functionality

Vulcan is a specialized application designed to streamline the creation, management, and implementation of security compliance documentation. It serves as a collaborative platform for developing Security Technical Implementation Guides (STIGs) derived from Security Requirements Guides (SRGs), while simultaneously generating associated automation and testing code.

### Primary Functions

1. **Structured Security Documentation Development**
   - Create and manage Projects representing security documents for components or products
   - Derive specific implementation guidance (STIGs) from general security requirements (SRGs)
   - Support version-controlled documentation with standard release patterns (V1R1, V1R2, V2R1, etc.)
   - Enable collaborative editing of structured security requirements

2. **Compliance Automation Integration**
   - Generate InSpec code for automated compliance testing of requirements
   - Support for adding Ansible automation tasks for security implementation
   - Create exportable profiles for continuous compliance verification
   - Bridge the gap between documentation and implementation

3. **Collaborative Workflow**
   - Git-flow style peer review process for components (STIGs)
   - Role-based access control (editors, reviewers, etc.)
   - Historical tracking of changes and approvals
   - Diff functionality between component versions

4. **Knowledge Sharing and Reuse**
   - Cross-reference related requirements from different STIGs with the same SRG ID
   - Enable users to see implementation examples from similar systems
   - Support searching and discovery across the knowledge base
   - Facilitate standardization across similar technologies
   - Reference the relationship between requirements and NIST controls via CCIs

5. **Export and Integration**
   - XCCDF document XML format (industry standard for STIGs/SRGs)
   - Multiple spreadsheet output formats for review and import/export
   - InSpec profiles for automated compliance testing
   - Changelog history for audit and peer review
   - Potential Ansible playbook generation

## System Architecture and Data Model

### Key Entities

1. **Project**
   - Represents a security document for a product or component
   - Contains one or more Components
   - Has metadata about the overall product

2. **Component**
   - Represents a specific security guidance document (STIG)
   - Derived from an SRG (Security Requirements Guide)
   - Contains many Rules
   - Has version information (V1R1, V1R2, etc.)

3. **Rule/Requirement**
   - Represents a specific security requirement (not a security control)
   - Contains implementation details for a general security requirement
   - May include InSpec test code
   - May include Ansible implementation code
   - Linked to an SRG ID
   - Connected to NIST 800-53 controls through CCIs (Control Correlation Identifiers)

4. **Security Requirements Guide (SRG)**
   - General security requirements for technology types
   - Source material for STIGs
   - Relatively stable across versions
   - Categorized by technology type (OS, Database, Web Server, etc.)
   - Contains mappings to CCIs (Control Correlation Identifiers)
   - CCIs link requirements to NIST 800-53 security controls

5. **Users and Roles**
   - Collaborators with different permissions
   - Project administrators, editors, reviewers, etc.
   - Permission model for different document lifecycle stages

### Document Workflow

1. **Creation**
   - Project setup and component definition
   - Import or association with appropriate SRG
   - Initial requirement tailoring

2. **Development**
   - Tailoring general requirements to specific implementations
   - Writing InSpec code for automated testing
   - Adding Ansible tasks for implementation
   - Collaborative editing and review

3. **Review**
   - Git-flow style peer review process
   - Comment and approval workflow
   - Version tracking and history

4. **Publication**
   - Exporting to standard formats (XCCDF, Excel, etc.)
   - Generating InSpec profiles
   - Creating documentation and changelog artifacts

### Collaboration Patterns

1. **Form-Based Structured Editing**
   - Users edit specific sub-elements through forms, not simultaneous text editing
   - Structured fields for different aspects of requirements
   - Code editors for InSpec/Ansible sections

2. **Project Team Collaboration**
   - Multiple team members working on different sections
   - Need for awareness of who is editing which sections
   - Review and approval workflows

3. **Cross-Project Knowledge Sharing**
   - Ability to see related requirements across projects
   - Reference implementations from similar systems with the same SRG ID
   - Standardization across related technologies
   - Visibility into how different teams implement the same security requirement

### Integration Points

1. **Source Systems**
   - Import from XCCDF documents
   - Import from spreadsheets
   - Reference official SRGs

2. **Export Targets**
   - XCCDF XML export
   - Spreadsheet exports
   - InSpec profile generation
   - Potential Ansible playbook export
   - Documentation generation

3. **External Tools**
   - InSpec for compliance testing
   - Ansible for automation
   - Continuous integration systems
   - Documentation platforms

## Technical Environment

### Current Stack

- Rails backend
- Vue 2 frontend with Bootstrap Vue components
- PostgreSQL database
- XCCDF XML processing capabilities
- InSpec DSL support
- Version control and diff functionality

### Modernization Goals

1. **Frontend Modernization**
   - Upgrade to Vue 3 and modern component libraries
   - Enhance real-time collaboration features
   - Improve user experience and performance

2. **Backend Enhancements**
   - Upgrade Rails and dependencies
   - Optimize database design
   - Implement comprehensive API layer
   - Enhance security features

3. **Feature Additions**
   - Ansible automation support
   - Enhanced real-time collaboration
   - Improved diff and version comparison tools
   - Additional export formats and integration points

4. **Developer Experience**
   - Modern build tools and processes
   - Comprehensive testing
   - Documentation and onboarding improvements

## Unique Considerations

1. **Security and Compliance**
   - Application deals with security-sensitive content
   - May operate in regulated environments
   - Needs to maintain its own security posture

2. **Structured Data Complexity**
   - Hierarchical document structures
   - Cross-references between requirements
   - Version control requirements
   - Compliance with standards and formats

3. **Specialized Domain Knowledge**
   - Security compliance expertise
   - InSpec and Ansible knowledge
   - XCCDF and related standards
   - Security implementation patterns

4. **Collaboration Requirements**
   - Structured, form-based collaboration rather than free-form editing
   - Review and approval workflows
   - Change tracking and auditing
   - Knowledge sharing across teams

This overview serves as a foundation for understanding Vulcan's purpose, functionality, and requirements, which will inform architectural and design decisions throughout the modernization process.