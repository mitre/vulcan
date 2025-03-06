# Vulcan Development Guide

## Reference Documentation
- **Vulcan-System-Overview.md**: Comprehensive description of Vulcan's purpose, features, and architecture
- **Vulcan-Modernization-Roadmap.md**: Phased plan for upgrades with milestones and decision points
- **Vulcan-Design-Decisions.md**: Technical decisions and options for the modernization project
- **MIGRATION_INVENTORY.md**: Inventory of JavaScript pack tags that need migration
- **webpacker-to-jsbundling-migration-guide.md**: Practical guide for migrating from Webpacker

## Build & Test Commands
- Run server: `bundle exec rails s`
- Run all tests: `bundle exec rails db:create db:schema:load spec`
- Run single test: `bundle exec rspec path/to/spec_file.rb:line_number`
- Run specific file: `bundle exec rspec path/to/spec_file.rb`
- Run JS tests: `yarn test`
- Run Ruby linting: `bundle exec rubocop`
- Run JS linting: `yarn lint`

## Code Style Guidelines
### Ruby
- Use snake_case for variables and methods
- Use CamelCase for classes
- Prefix boolean methods with verbs (can_?, is_?)
- Use custom error classes in app/errors/
- Place `frozen_string_literal: true` at the top of files

### JavaScript/Vue
- Use PascalCase for component names and files
- Use camelCase for variables and methods
- Define props with types and required status
- Use Single File Component format (.vue)
- Scope component styles with scoped attribute

### Testing
- Group tests with describe/context/it blocks
- Use Factory Bot for test data
- Test validations, associations, and methods separately