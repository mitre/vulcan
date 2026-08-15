# User Guide

## Comprehensive Vulcan Training

For detailed user guidance on using Vulcan, please visit the official MITRE SAF Training site:

**🎓 [Vulcan User Guide - SAF Training](https://mitre.github.io/saf-training/courses/guidance/)**

The SAF Training site provides comprehensive coverage of:

- Getting Started with Vulcan
- Creating and Managing Projects
- Working with Components
- Writing Security Controls (Rules)
- Using the InSpec Integration
- Collaboration Features
- Importing and Exporting STIGs
- Best Practices and Workflows

## Quick Reference

### Core Concepts

- **Projects**: Top-level containers for organizing security documentation work
- **Components**: Documents in progress — a STIG being authored for a system element, or an SRG being authored from core SRGs
- **Rules**: Individual security controls with check/fix text and InSpec code
- **SRGs**: High-level Security Requirements Guides from DISA — the basis STIG components implement, and themselves authorable in Vulcan (see the [SRG Authoring Workflow](../disa-process/srg-authoring))
- **STIGs**: Specific Security Technical Implementation Guides for technologies

### Common Tasks

| Task | Description |
|------|-------------|
| Create Project | Start a new documentation effort |
| Import SRG | Load security requirements |
| Create Component | Add system elements |
| Author an SRG | Derive a new SRG from core SRGs |
| Write Controls | Document check/fix procedures |
| Add InSpec | Create automated validation |
| Export STIG | Generate XCCDF output |

### Additional Resources

For more detailed guidance on specific topics, please visit the [SAF Training site](https://mitre.github.io/saf-training/courses/guidance/).

## Getting Help

- **Training**: https://mitre.github.io/saf-training/courses/guidance/
- **GitHub Issues**: https://github.com/mitre/vulcan/issues
- **Email**: saf@mitre.org