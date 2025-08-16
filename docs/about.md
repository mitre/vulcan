# About Vulcan

## What is Vulcan?

Vulcan is a comprehensive tool designed to streamline the creation of Security Technical Implementation Guide (STIG) ready security guidance documentation and InSpec automated validation profiles. It bridges the gap between security requirements and practical implementation, enabling organizations to develop both human-readable instructions and machine-readable validation code simultaneously.

## Purpose

Vulcan models the STIG creation process, facilitating the alignment of security controls from high-level DISA Security Requirements Guides (SRGs) into STIGs tailored to specific system components. Content developed with Vulcan can be submitted to DISA for peer review and formal publication as official STIGs.

## Key Capabilities

### 📋 STIG Process Modeling
Manages the complete workflow between vendors and sponsors for STIG development.

### 🔍 InSpec Integration
Write and test validation code locally or across SSH, AWS, and Docker targets directly within the platform.

### 📊 Control Management
Track control status, revision history, and relationships between requirements and implementations.

### 👥 Collaborative Authoring
Multiple authors can work on control sets with built-in review workflows and approval processes.

### 🔗 Cross-Reference Capabilities
Look up related controls across published STIGs to ensure consistency and completeness.

### 📚 STIG Library
View and reference DISA-published STIG content for guidance and examples.

## Who Uses Vulcan?

- **Security Teams**: Create and maintain security documentation
- **Compliance Officers**: Ensure systems meet STIG requirements
- **System Administrators**: Implement and validate security controls
- **Developers**: Build security into applications from the start
- **Auditors**: Verify compliance with security standards

## MITRE Security Automation Framework

Vulcan is part of the [MITRE Security Automation Framework (SAF)](https://saf.mitre.org/), a comprehensive suite of tools and libraries designed to automate security validation and compliance checking.

### Related SAF Projects

- **[InSpec](https://www.inspec.io/)**: Compliance automation framework
- **[Heimdall](https://github.com/mitre/heimdall2)**: Security results visualization
- **[SAF CLI](https://github.com/mitre/saf-cli)**: Command-line tools for security automation
- **[InSpec Profile Development](https://github.com/mitre/inspec-profile-developer-course)**: Training resources

## History

Vulcan was developed by MITRE Corporation to address the need for a streamlined STIG creation process. It has evolved from internal tooling to a comprehensive platform used by organizations across the defense industrial base and beyond.

## License

© 2022-2025 The MITRE Corporation.

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE.md) file for details.

**Approved for Public Release; Distribution Unlimited. Case Number 18-3678.**

## Support

- **Issues**: [GitHub Issues](https://github.com/mitre/vulcan/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mitre/vulcan/discussions)
- **Wiki**: [Project Wiki](https://github.com/mitre/vulcan/wiki)
- **Security Issues**: saf-security@mitre.org
- **General Inquiries**: saf@mitre.org