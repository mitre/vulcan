# Contributing to Vulcan

First off, thank you for considering contributing to Vulcan! It's people like you that make Vulcan such a great tool for the security community.

## Code of Conduct

By participating in this project, you are expected to uphold our [Code of Conduct](./CODE_OF_CONDUCT.md):

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** to demonstrate the steps
- **Describe the behavior you observed** and why it's a problem
- **Explain which behavior you expected** instead
- **Include screenshots and logs** if possible
- **Include your environment details** (OS, Ruby version, Rails version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Provide specific examples** to demonstrate the enhancement
- **Describe the current behavior** and how your suggestion improves it
- **List any alternatives** you've considered

### Security Vulnerabilities

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them to our security team at **saf-security@mitre.org**. You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

Please include:
- Type of issue (e.g., buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the issue
- Location of affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue

## Development Process

### Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone git@github.com:your-username/vulcan.git
   cd vulcan
   ```
3. **Add the upstream repository**:
   ```bash
   git remote add upstream git@github.com:mitre/vulcan.git
   ```
4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Development Setup

1. **Install dependencies**:
   ```bash
   bundle install
   pnpm install
   ```

2. **Setup database**:
   ```bash
   bin/setup
   rails db:seed
   ```

3. **Start development server**:
   ```bash
   foreman start -f Procfile.dev
   ```

### Making Changes

1. **Follow the coding standards**:
   - Ruby: Follow RuboCop rules (run `bundle exec rubocop`)
   - JavaScript: Follow ESLint rules (run `pnpm lint`)
   - Vue: Follow Vue style guide
   - Write clear, self-documenting code
   - Add comments for complex logic

2. **Write tests**:
   - Add RSpec tests for Ruby code
   - Ensure all tests pass: `bundle exec rspec`
   - Maintain or improve code coverage

3. **Update documentation**:
   - Update README.md if needed
   - Update ENVIRONMENT_VARIABLES.md for new config options
   - Add inline documentation for public methods
   - Update CHANGELOG.md

4. **Commit your changes**:
   ```bash
   git add .
   git commit -m "feat: add amazing feature

   - Detailed description of what changed
   - Why this change was needed
   - Any breaking changes or migrations required"
   ```

   Follow conventional commits:
   - `feat:` New feature
   - `fix:` Bug fix
   - `docs:` Documentation changes
   - `style:` Code style changes (formatting, etc.)
   - `refactor:` Code refactoring
   - `test:` Test additions or corrections
   - `chore:` Maintenance tasks

### Submitting Changes

1. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a Pull Request**:
   - Go to your fork on GitHub
   - Click "New pull request"
   - Select your feature branch
   - Fill in the PR template with:
     - Description of changes
     - Related issue numbers
     - Testing performed
     - Screenshots (if UI changes)

3. **PR Review Process**:
   - A maintainer will review your PR
   - Address any requested changes
   - Once approved, a maintainer will merge your PR

## Testing Guidelines

### Running Tests

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/models/user_spec.rb

# Run tests with coverage
COVERAGE=true bundle exec rspec
```

### Writing Tests

- Write tests first (TDD) when possible
- Test both happy path and edge cases
- Keep tests focused and isolated
- Use factories instead of fixtures
- Mock external services
- Ensure tests are deterministic

## Style Guidelines

### Ruby Style

We use RuboCop to enforce Ruby style:

```bash
# Check for violations
bundle exec rubocop

# Auto-fix violations
bundle exec rubocop --autocorrect-all
```

Key conventions:
- 2 spaces for indentation
- No trailing whitespace
- Meaningful variable and method names
- Prefer single quotes for strings without interpolation

### JavaScript/Vue Style

We use ESLint and Prettier:

```bash
# Check and fix JavaScript
pnpm lint

# Format code
pnpm format
```

Key conventions:
- 2 spaces for indentation
- Use modern ES6+ syntax
- Follow Vue.js style guide
- Meaningful component and variable names

## Database Changes

When making database changes:

1. Create a migration:
   ```bash
   rails generate migration AddFieldToModel field:type
   ```

2. Write reversible migrations when possible

3. Test migrations:
   ```bash
   rails db:migrate
   rails db:rollback
   rails db:migrate
   ```

4. Update seeds if needed: `db/seeds.rb`

## Documentation

- **Code Comments**: Add comments for complex logic
- **Method Documentation**: Use YARD format for Ruby
- **API Documentation**: Update if endpoints change
- **User Documentation**: Update wiki for user-facing changes

## Release Process

Maintainers handle releases, but you can help by:

1. Keeping CHANGELOG.md updated
2. Following semantic versioning in PRs
3. Highlighting breaking changes
4. Testing release candidates

## Questions?

Feel free to:
- Open a [GitHub Discussion](https://github.com/mitre/vulcan/discussions)
- Email us at saf@mitre.org
- Check our [Wiki](https://github.com/mitre/vulcan/wiki)

## Recognition

Contributors are recognized in:
- GitHub's contributor graph
- Release notes
- Our annual contributor report

Thank you for contributing to Vulcan and helping make security automation better for everyone!

---

<p align="center">
  Part of the <a href="https://saf.mitre.org/">MITRE Security Automation Framework</a>
</p>