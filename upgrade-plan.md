# Rails + Vue.js Application Upgrade Plan

The Goal: A Modern, Integrated Asset Pipeline

Your goal is to move to a solution that is:

Actively Maintained: Ensuring long-term support and bug fixes.
Integrated: Ideally, it should leverage the Rails asset pipeline more directly, reducing the need for a separate Node.js-based build system.
Performant: Efficient compilation and serving of assets.
Well-Documented: Easy to understand and use.
Upgradable: Using a system that will not have this problem in the future.
Your Options (Post-Webpacker):

Rails currently promotes three primary alternatives to Webpacker:

Propshaft:

What it is: The new default asset pipeline in Rails 7+ for non-JavaScript assets (images, CSS, fonts, etc.)
How it relates to Webpacker: It is the solution that replaced sprockets-rails. It takes over serving up non JS assets from sprockets-rails
JavaScript Handling: Propshaft is primarily for non-JavaScript assets. It doesn't bundle JavaScript directly. It is designed to work in conjunction with importmaps.
Strengths:
Built-in: Part of Rails core.
Simple: Configuration is very minimal.
Fast: Optimized for static asset serving.
Modern: Takes advantage of newer browser support to deliver newer more effiecent code.
Weaknesses:
Not for JavaScript Bundling: It delegates JavaScript bundling to another tool.
Importmaps:

What it is: A browser-native feature that allows you to import JavaScript modules directly from URLs, no bundling required for the initial development.
How it relates to Webpacker: A completely different philosophy. Instead of bundling all JS, it lets the browser load modules as needed.
Strengths:
No Build Step (Initially): Ideal for small to medium projects and rapid development.
Leverages Browser Capabilities: No need for a separate bundler during development.
Simple Dependency Management: You point to the dependencies directly, in most cases, through a CDN.
Weaknesses:
Not Ideal for Large/Complex Applications: Can lead to a waterfall of requests in production if not optimized.
Production Optimization: Requires a separate step (e.g., bin/rails javascript:build) to bundle for production.
Compatibility Concerns: Older browsers may not support it without a polyfill (though most modern browsers do).
Build Step In Production: To get the best performance in production, you will still need a build step.
jsbundling-rails (with esbuild or rollup):

What it is: A Rails gem that provides integration with JavaScript bundlers like esbuild or rollup.
How it relates to Webpacker: It fulfills the JavaScript bundling role that Webpacker previously filled, but it's designed to be much more lightweight and integrated.
Strengths:
Modern Bundlers: esbuild and rollup are known for their speed and efficiency.
Clear Separation of Concerns: Rails handles the asset pipeline; the bundler handles JavaScript.
Production-Ready: Bundles your JavaScript into optimized files.
Well Supported: Both of these bundlers are used widely outside of the rails community.
Weaknesses:
Requires Setup: You have to choose a bundler and configure it.
More Configuration: More options and knobs than importmaps.
Which is the Best Option for You?

The "best" choice depends on your specific application's size, complexity, and your team's experience. However, considering the goals outlined above, here's my recommendation:

The Recommendation: jsbundling-rails (with esbuild or rollup) + Propshaft

This combination is the most robust and future-proof solution for the vast majority of Rails applications.

Why this combination?

Handles All Assets:
Propshaft: Takes care of your images, CSS, fonts, etc. It's part of Rails core, so it's a natural fit.
jsbundling-rails: Bundles your JavaScript with modern tools like esbuild (fast, minimal config) or rollup (more customizable).
Production Performance: esbuild and rollup provide excellent production-level bundling, code splitting, and optimization.
Clean Separation: You have a clear line between asset serving (Propshaft) and JavaScript bundling (jsbundling-rails).
Future-Proof: This combination is well-supported by the Rails core team and is the recommended path forward.
Widely Used: esbuild and rollup are not rails specific. This will make finding resources and new people to help maintain this system easier.
When Might Importmaps Be a Good Choice?

Small to medium-sized applications: If your application's JavaScript complexity is relatively low, importmaps can be an excellent starting point.
Rapid Prototyping: The lack of an initial build step is fantastic for quick development.
Limited JavaScript: If you're primarily using Rails' built-in helpers for interactivity and don't have a lot of custom JS code, importmaps may be sufficient.
How to Proceed with Migration:

Remove Webpacker: Follow the official Rails guide for removing Webpacker.
Install Propshaft: It should already be installed.
Install jsbundling-rails:
bundle add jsbundling-rails
rails javascript:install:esbuild # Or: rails javascript:install:rollup
Move Assets:
Move any image, video, font, css files to app/assets
Move any js files to app/javascript
Update Imports: Update your application.js file to include any js you are using.
Build: Run bin/rails javascript:build to build the javascript for production.
In Summary

While importmaps have their niche, for a robust, production-ready, and long-term solution when migrating away from Webpacker, jsbundling-rails with esbuild or rollup paired with Propshaft is the recommended path. It gives you the best balance of simplicity, performance, and maintainability. I would recommend starting with esbuild as it will need less configuation, and move to rollup only if needed.

## 1. Project Assessment and Planning

### 1.1 Dependencies Audit

* [ ] Ruby gems (List gems and versions)
* [ ] Node.js packages (List packages and versions)

### 1.2 Compatibility Check

* [ ] Research compatibility of dependencies with target Rails, Ruby, and Node.js versions.
* [ ] Note any potential conflicts or breaking changes.

### 1.3 Upgrade Strategy

* [ ] Choose upgrade strategy: Gradual or Direct.
* [ ] Document the chosen strategy.

### 1.4 Testing Strategy

* [ ] Unit tests (Rails and Vue.js)
* [ ] Integration tests (Rails and Vue.js interaction)
* [ ] End-to-end tests (Cypress, Selenium, etc.)
* [ ] **Define specific tests for upgrade compatibility (dependency changes, performance regressions).**

### 1.5 Rollback Plan

* [ ] Define a clear rollback strategy.

### 1.6 Documentation

* [ ] Document the entire upgrade process.

## 2. Ruby and Rails Upgrade

### 2.1 Ruby Upgrade

* [ ] Install target Ruby version using rvm or rbenv.
* [ ] Update `.ruby-version` file.
* [ ] Run `bundle install` and resolve conflicts.
* [ ] **Run Rails tests after Ruby upgrade.**

### 2.2 Rails Upgrade

* [ ] Update Rails version in `Gemfile`.
* [ ] Run `bundle update rails`.
* [ ] Run `rails app:update`.
* [ ] Address deprecated features and breaking changes.
* [ ] Run Rails tests.
* [ ] **Remove Webpacker: Follow the official Rails guide for removing Webpacker.**
* [ ] **Install jsbundling-rails: `bundle add jsbundling-rails`**
* [ ] **Run `rails javascript:install:esbuild` (or `rails javascript:install:rollup`)**

## 3. Node.js and Vue.js Upgrade

### 3.1 Node.js Upgrade

* [ ] Install target Node.js version using nvm.
* [ ] Update `.nvmrc` file.
* [ ] Run `npm install` or `yarn install`.
* [ ] **Run Vue.js tests after Node.js upgrade.**

### 3.2 Vue.js Upgrade

* [ ] Update Vue.js version and related libraries in `package.json`.
* [ ] Run `npm update` or `yarn upgrade`.
* [ ] Address deprecated features and breaking changes.
* [ ] Update Vue CLI if necessary.
* [ ] Run Vue.js tests.

## 4. Testing and Refinement

* [ ] Run all tests (unit, integration, end-to-end).
* [ ] Conduct code reviews.
* [ ] Perform performance testing.
* [ ] Implement monitoring.

## 5. Deployment

### 5.1 Deploy to Staging

* [ ] Deploy upgraded application to staging environment.

### 5.2 Monitor Staging

* [ ] Monitor staging environment for issues.

### 5.3 Deploy to Production

* [ ] Deploy upgraded application to production.

### 5.4 Monitor Production

* [ ] Monitor production environment closely after deployment.

## 6. Migration from Webpacker to jsbundling-rails + Propshaft

### 6.1 Preparation

1. **Backup Your Application:**
    * Ensure you have a complete backup of your application, including the database.
    * Use version control (e.g., git) to track changes.

### 6.1.2 Review Dependencies

1. **Audit Ruby Gems:**
    * Review the `Gemfile.lock` for the current Ruby gems and their versions.
    * Identify any gems that might be affected by the migration to Propshaft and jsbundling-rails.
    * Ensure all gems are compatible with Rails 8 and Ruby 3.4.x.

    ```ruby
    # Gemfile.lock
    # ...existing code...
    gem 'webpacker', '~> 5.0'
    # ...existing code...
    ```

    * The `webpacker` gem will be removed as part of the migration.

#### Gems Audit Report

##### Close Attention Required

1. Webpacker (5.4.3)

* Issue: This gem will be removed as part of the migration to jsbundling-rails and Propshaft.
* Action: Ensure that all JavaScript assets are correctly migrated and configured with the new bundling tools.
  
2. Nokogiri (1.17.2)

* Issue: Nokogiri is a complex gem with native extensions. Ensure compatibility with the new Ruby version and operating system.
* Action: Test thoroughly after upgrading to ensure there are no issues with XML/HTML parsing.

3. Puma (5.6.7)

* Issue: As the web server, any issues with Puma can affect the entire application.
* Action: Monitor performance and stability closely after the upgrade.

4. Devise (4.8.1)

* Issue: Authentication is critical, and any issues with Devise can impact user access.
* Action: Test all authentication flows thoroughly, including sign-up, login, password reset, and role-based access.

5. OmniAuth Gems (omniauth, omniauth-github, omniauth-rails_csrf_protection, omniauth_openid_connect)

* Issue: These gems handle third-party authentication, which can be sensitive to changes in dependencies.
* Action: Test all third-party authentication flows thoroughly to ensure they work as expected.

6. Spring (4.2.1) and Spring-Watcher-Listen (2.1.0)

* Issue: Spring can sometimes cause issues with code reloading in development.
* Action: Monitor development environment for any issues with code reloading and consider disabling Spring if problems arise.

7. Nokogiri-Happymapper (0.9.0)

Issue: This gem depends on Nokogiri and may have specific compatibility requirements.
Action: Test XML parsing and mapping functionality thoroughly.

8. Ruh-Roo (3.0.1)

* Issue: This gem is less commonly used and may have specific compatibility requirements.
* Action: Test all functionality that depends on Ruh-Roo thoroughly.

##### Group 1: Rails Core Gems

* Compatibility: Compatible with Rails 8 and Ruby 3.4.x.
* Notes: Actively maintained and supports recent versions of Rails and Ruby.

###### Compatible and Supported Core Gems

* activerecord-import (1.3.0)
* amoeba (3.2.0)
* audited (5.3.3)
* brakeman (5.2.1)
* capybara (3.40.0)
* database_cleaner-active_record (2.0.1)
* devise (4.8.1)
* factory_bot_rails (5.2.0)
* ffaker (2.20.0)
* gitlab_omniauth-ldap (2.2.0)
* haml-rails (2.0.1)
* jbuilder (2.11.5)
* letter_opener (1.7.0)
* mitre-inspec-objects (0.3.3)
* nokogiri (1.17.2)
* nokogiri-happymapper (0.9.0)
* omniauth (2.1.1)
* omniauth-github (2.0.0)
* omniauth-rails_csrf_protection (1.0.1)
* omniauth_openid_connect (0.6.1)
* pg (1.3.2)
* pry (0.14.1)
* rest-client (2.1.0)
* rspec-mocks (3.11.0)
* rspec-rails (4.0.2)
* rubocop (1.25.1)
* rubocop-performance (1.13.2)
* rubocop-rails (2.13.2)
* rubyzip (2.4.1)
* ruh-roo (3.0.1)
* selenium-webdriver (4.26.0)
* settingslogic (2.0.9)
* simplecov (0.21.2)
* slack-ruby-client (1.0.0)
* slack_block_kit (0.3.3)
* spring (4.2.1)
* spring-watcher-listen (2.1.0)
* turbolinks (5.2.1)
* tzinfo-data (1.2021.5)
* web-console (4.2.0)

##### Group 2: Rails Ecosystem Gems

* Compatibility: Compatible with Rails 8 and Ruby 3.4.x.
* Notes: Part of the Rails ecosystem and is regularly updated to support new versions.

###### Compatible and Supported Ecosystem Gems

* bootsnap (1.10.3)
* puma (5.6.7)

##### Group 3: Third-Party Gems

* Compatibility: Compatible with Rails 8 and Ruby 3.4.x.
* Notes: Widely used and supports recent versions of Ruby.

###### Compatible and Supported Third-Party Gems

* byebug (11.1.3)
* concurrent-ruby (1.3.4)
* fast_excel (0.4.0)
* highline (2.0.3)
* listen (3.9.0)
* ox (2.14.9)
* rexml (3.4.0)

1. **Audit Node.js Packages:**
    * Review the `package.json` for the current Node.js packages and their versions.
    * Identify any packages that might be affected by the migration to esbuild or rollup.
    * Ensure all packages are compatible with the target Node.js version.

    ```json
    // package.json
    {
      // ...existing code...
      "dependencies": {
        "webpack": "^5.0.0",
        "webpack-cli": "^4.0.0"
        // ...existing code...
      }
    }
    ```

    * The `webpack` and `webpack-cli` packages will be removed as part of the migration.

2. **Check for Compatibility:**
    * Research compatibility of dependencies with target Rails, Ruby, and Node.js versions.
    * Note any potential conflicts or breaking changes.
    * Update dependencies to their latest versions if necessary.

3. **Document Findings:**
    * Document any dependencies that need to be updated or replaced.
    * Note any potential issues or considerations for the migration.

By following these steps, you can ensure that your dependencies are compatible with the new asset pipeline and bundling tools, minimizing potential issues during the migration process.

### 6.2 Remove Webpacker

1. **Remove Webpacker Gem:**
    * Remove the `webpacker` gem from your `Gemfile`.

    ```ruby
    # Gemfile
    # gem 'webpacker'
    ```

2. **Remove Webpacker Configuration:**
    * Delete the `config/webpacker.yml` file.
    * Remove the `config/webpack` directory.

3. **Remove Webpacker Packs:**
    * Delete the `app/javascript/packs` directory.

### 6.3 Install Propshaft

1. **Add Propshaft Gem:**
    * Add the `propshaft` gem to your `Gemfile`.

    ```ruby
    # Gemfile
    gem 'propshaft'
    ```

2. **Install Propshaft:**
    * Run `bundle install` to install the gem.
    * Run `rails propshaft:install` to set up Propshaft.

3. **Move Assets:**
    * Move any images, fonts, and CSS files from `app/javascript` to `app/assets`.

### 6.4 Install jsbundling-rails

1. **Add jsbundling-rails Gem:**
    * Add the `jsbundling-rails` gem to your `Gemfile`.

    ```ruby
    # Gemfile
    gem 'jsbundling-rails'
    ```

2. **Install jsbundling-rails:**
    * Run `bundle install` to install the gem.
    * Choose and install a bundler (esbuild or rollup):

    ```sh
    rails javascript:install:esbuild
    # or
    rails javascript:install:rollup
    ```

3. **Move JavaScript Files:**
    * Move any JavaScript files from `app/javascript/packs` to `app/javascript`.

4. **Update JavaScript Imports:**
    * Update your `application.js` file to include any necessary JavaScript imports.

### 6.5 Update Application Configuration

1. **Update Asset Pipeline Configuration:**
    * Ensure your `config/application.rb` is configured to use Propshaft.

    ```ruby
    # config/application.rb
    config.assets.paths << Rails.root.join("app", "assets")
    ```

2. **Update Layouts:**
    * Update your application layout files to include the new asset paths.

    ```erb
    <!-- app/views/layouts/application.html.erb -->
    <%= javascript_include_tag "application", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    ```

### 6.6 Testing and Verification

1. **Run Tests:**
    * Run your Rails and Vue.js tests to ensure everything is working correctly.

    ```sh
    bundle exec rspec
    yarn test
    ```

2. **Manual Testing:**
    * Manually test your application to verify that assets are being served correctly and functionality is intact.

### 6.7 Deployment

1. **Deploy to Staging:**
    * Deploy the updated application to a staging environment.
    * Monitor for any issues and resolve them.

2. **Deploy to Production:**
    * Once verified in staging, deploy the application to production.
    * Monitor the production environment closely after deployment.

### 6.8 Documentation and Cleanup

1. **Update Documentation:**
    * Document the migration process and any changes made to the application.

2. **Cleanup:**
    * Remove any unused files and configurations related to Webpacker.

By following this detailed plan, you can successfully migrate from Webpacker to jsbundling-rails (with esbuild or rollup) + Propshaft, ensuring a modern, efficient, and maintainable asset pipeline for your Rails + Vue.js application.
