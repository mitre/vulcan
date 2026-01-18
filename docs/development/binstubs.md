# Binstubs in Vulcan

## What Are Binstubs?

Binstubs (short for "binary stubs") are wrapper scripts in the `bin/` directory that execute gem commands in the context of your project's bundle. They eliminate the need for `bundle exec` and ensure all team members use the same gem versions.

## Policy: Binstubs Are Committed to Git ✅

**Vulcan follows the official Rails standard**: All binstubs in `bin/` are committed to version control.

### Why We Commit Binstubs

1. **Team Consistency** - All developers use identical executable versions
2. **Rails Standard** - Official Rails convention since Rails 4.0 (2013)
3. **CI/CD Simplicity** - CI systems get correct executables automatically
4. **Onboarding Speed** - New developers run `bin/setup` and they're ready
5. **No Bundle Exec** - Use `bin/rails` instead of `bundle exec rails`
6. **Custom Scripts** - Project-specific automation scripts versioned with code

### Official Rails Position

From the [Rails Upgrading Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html):
> "You may need to remove bin/ from your .gitignore to add these files to source control."

From DHH's [original Rails commit introducing bin/](https://github.com/rails/rails/commit/009873aec89a4b843b41accf616b42b7a9917ba8):
> "Executable scripts are versioned code like the rest of your app."

From [Bundler documentation](https://bundler.io/man/bundle-binstubs.1.html):
> "You are encouraged to check these binstubs in version control so your colleagues might benefit from them."

## Current Binstubs (12 files)

### Rails Defaults
- `bin/rails` - Rails command runner
- `bin/rake` - Rake task runner
- `bin/setup` - Project setup script (runs on initial clone)

### Gem-Specific Binstubs
- `bin/bundle` - Bundler wrapper
- `bin/rubocop` - Ruby style checker
- `bin/brakeman` - Security scanner
- `bin/vite` - Vite.js asset bundler

### Custom Project Scripts
- `bin/dev` - Start development server with all services
- `bin/docker-entrypoint` - Container initialization script
- `bin/vulcan` - Custom Vulcan CLI tool
- `bin/test-okta-discovery` - OIDC discovery testing utility
- `bin/fix_whitespace.py` - Python script for whitespace cleanup

## Usage

### Running Commands

```bash
# Use binstubs directly (recommended)
bin/rails console
bin/rake db:migrate
bin/rubocop --autocorrect-all
bin/rspec spec/

# Instead of bundle exec (old way)
bundle exec rails console    # ❌ Verbose
bundle exec rake db:migrate  # ❌ Requires typing
```

### Generating New Binstubs

Only generate binstubs you actually need:

```bash
# Generate a specific gem's binstub
bundle binstubs rspec-core

# Then commit it
git add bin/rspec
git commit -m "chore: Add rspec binstub"
```

**Don't use `bundle binstubs --all`** - this generates binstubs for every gem in your bundle (hundreds of files).

## For New Developers

After cloning the repository:

```bash
# 1. Setup installs dependencies and creates databases
bin/setup

# 2. Start development server
bin/dev

# 3. Run tests
bin/rspec

# 4. Run linter
bin/rubocop
```

All binstubs are already in the repository, ready to use.

## For Contributors

When you add a new gem that has CLI commands you'll use regularly:

1. Generate its binstub: `bundle binstubs <gem-name>`
2. Verify it works: `bin/<command> --version`
3. Commit it: `git add bin/<command> && git commit -m "chore: Add <gem> binstub"`

Examples:
- Adding Sidekiq: `bundle binstubs sidekiq`
- Adding Puma: `bundle binstubs puma`
- Adding Foreman: `bundle binstubs foreman`

## Troubleshooting

### Binstub Out of Date

If you see "Your binstub is out of date", regenerate it:

```bash
# Regenerate specific binstub
bundle binstubs <gem-name> --force

# Regenerate Rails binstubs
rails app:update:bin
```

### Permission Denied

Binstubs need executable permissions:

```bash
chmod +x bin/*
git add bin/
git commit -m "fix: Restore executable permissions on binstubs"
```

### Wrong Ruby/Gem Version

Binstubs use the shebang `#!/usr/bin/env ruby` which respects your current Ruby version manager (rbenv, asdf, etc.). Make sure you're using the correct Ruby version:

```bash
# Check Ruby version
ruby -v  # Should match .ruby-version file

# If using rbenv
rbenv versions
rbenv local 3.3.9

# If using asdf
asdf current ruby
asdf local ruby 3.3.9
```

## References

- [Understanding Binstubs in Rails (Osiel Nava)](https://osielnava.com/posts/rails-binstubs/)
- [Understanding binstubs (rbenv Wiki)](https://github.com/rbenv/rbenv/wiki/Understanding-binstubs)
- [Bundler binstubs documentation](https://bundler.io/man/bundle-binstubs.1.html)
- [Rails Upgrading Guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
- [Rails commit introducing bin/ directory](https://github.com/rails/rails/commit/009873aec89a4b843b41accf616b42b7a9917ba8)
