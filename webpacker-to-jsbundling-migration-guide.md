# Practical Guide: Migrating from Webpacker to jsbundling-rails + Propshaft

This guide provides practical implementation steps for transitioning from Webpacker to jsbundling-rails (with esbuild/rollup) + Propshaft in your Vulcan Rails + Vue.js application.

## 1. Understanding Your Current Webpacker Setup

Before you start the migration, it's important to understand how your application currently uses Webpacker:

1. **Analyze Entry Points**:

   ```bash
   # List your current Webpacker entry points
   find app/javascript/packs -name "*.js" -o -name "*.ts" -o -name "*.vue"
   ```

2. **Identify Dependencies**:

   ```bash
   # Check your package.json for JavaScript dependencies
   cat package.json | grep -A 50 "dependencies"
   ```

3. **Review Webpacker Configuration**:

   ```bash
   # Examine your Webpacker configuration
   cat config/webpacker.yml
   find config/webpack -type f
   ```

4. **Identify Asset References**:

   ```bash
   # Find all asset references in your views
   grep -r "javascript_pack_tag\|stylesheet_pack_tag" app/views/
   ```

## 2. Backing Up

Before making any changes, create a new git branch and commit the current state:

```bash
git checkout -b migrate-from-webpacker
git add .
git commit -m "Checkpoint before migrating from Webpacker to jsbundling-rails + Propshaft"
```

## 3. Removing Webpacker

1. **Update Gemfile**:

   ```ruby
   # Remove the Webpacker gem
   # gem 'webpacker', '~> 5.0'  # Delete or comment out this line
   ```

2. **Run bundle**:

   ```bash
   bundle install
   ```

3. **Clean Up Webpacker Files**:

   ```bash
   # Remove Webpacker configuration files
   rm config/webpacker.yml
   rm -rf config/webpack
   # Don't delete app/javascript/packs yet - we'll migrate these files
   ```

## 4. Installing Propshaft

1. **Add to Gemfile**:

   ```ruby
   gem 'propshaft'
   ```

2. **Run bundle**:

   ```bash
   bundle install
   ```

3. **Set up Propshaft**:

   ```bash
   rails propshaft:install
   ```

4. **Update Application Configuration**:

   ```ruby
   # In config/application.rb, ensure you have:
   config.assets.paths << Rails.root.join("app", "assets", "builds")
   config.assets.paths << Rails.root.join("app", "javascript")
   
   # Remove any Sprockets-specific configuration if present
   ```

## 5. Installing jsbundling-rails

We'll use esbuild for this example, which is generally faster and simpler than rollup:

1. **Add to Gemfile**:

   ```ruby
   gem 'jsbundling-rails'
   ```

2. **Run bundle**:

   ```bash
   bundle install
   ```

3. **Install JavaScript bundler (esbuild)**:

   ```bash
   rails javascript:install:esbuild
   ```

   This will:
   - Create a `package.json` entry for esbuild
   - Add build scripts
   - Create an initial `app/javascript/application.js` file

4. **Install Node dependencies**:

   ```bash
   yarn install
   # or
   npm install
   ```

## 6. Migrating JavaScript Files

Now comes the most critical part - migrating your JavaScript from Webpacker to jsbundling-rails:

1. **Create App JavaScript Structure**:

   ```bash
   # If not already created by the installer
   mkdir -p app/javascript
   ```

2. **Migrate Entry Points**:

   ```bash
   # For each entry point in app/javascript/packs/*.js
   
   # Example for application.js
   # Compare with the newly generated file
   cat app/javascript/packs/application.js
   cat app/javascript/application.js
   
   # Merge the content from your Webpacker entry point
   # into the new application.js
   ```

3. **Migrate Vue Components**:

   ```bash
   # Move Vue components to app/javascript
   mkdir -p app/javascript/components
   cp -r app/javascript/packs/components/* app/javascript/components/
   
   # Update import paths in all files
   find app/javascript -name "*.js" -o -name "*.vue" | xargs sed -i 's/from "..\/packs\/components/from "..\/components/g'
   ```

4. **Handle CSS/SCSS**:

   ```bash
   # Move CSS/SCSS files
   mkdir -p app/assets/stylesheets
   cp -r app/javascript/packs/stylesheets/* app/assets/stylesheets/
   
   # Update application.js to import CSS
   # For example:
   # import "../stylesheets/application.scss"
   ```

5. **Update application.js**:

   Create or update your `app/javascript/application.js` to include:

   ```javascript
   // Configure your imports here
   
   // Core dependencies
   import { createApp } from 'vue'
   
   // Your Vue components
   import ExampleComponent from './components/ExampleComponent.vue'
   
   // Initialize your application
   document.addEventListener('DOMContentLoaded', () => {
     // Mount Vue components
     const elements = document.querySelectorAll('[data-vue-component]')
     elements.forEach(element => {
       const componentName = element.dataset.vueComponent
       let component
       
       // Match component names to imports
       if (componentName === 'ExampleComponent') {
         component = ExampleComponent
       }
       
       if (component) {
         createApp(component, {
           ...element.dataset
         }).mount(element)
       }
     })
   })
   ```

## 7. Updating esbuild Configuration

1. **Configure esbuild for Vue.js**:

   Update your `package.json` build script:

   ```json
   "scripts": {
     "build": "esbuild app/javascript/*.* --bundle --sourcemap --outdir=app/assets/builds --public-path=assets",
     "build:css": "sass ./app/assets/stylesheets/application.scss:./app/assets/builds/application.css --no-source-map --load-path=node_modules"
   }
   ```

2. **Install Vue.js Plugin for esbuild**:

   ```bash
   npm install --save-dev esbuild-vue
   # or
   yarn add --dev esbuild-vue
   ```

3. **Create esbuild configuration**:

   Create a file `esbuild.config.js` at the project root:

   ```javascript
   // filepath: esbuild.config.js
   const esbuild = require('esbuild')
   const vuePlugin = require('esbuild-vue')

   esbuild.build({
     entryPoints: ['app/javascript/application.js'],
     bundle: true,
     outdir: 'app/assets/builds',
     plugins: [vuePlugin()],
     sourcemap: true,
     loader: {
       '.png': 'file',
       '.jpg': 'file',
       '.svg': 'file',
       '.gif': 'file',
       '.woff': 'file',
       '.woff2': 'file',
       '.ttf': 'file',
       '.eot': 'file',
     },
     define: {
       'process.env.NODE_ENV': `"${process.env.NODE_ENV || 'development'}"`
     },
     watch: process.argv.includes('--watch'),
   }).catch(() => process.exit(1))
   ```

4. **Update package.json scripts**:

   ```json
   "scripts": {
     "build": "node esbuild.config.js",
     "build:css": "sass ./app/assets/stylesheets/application.scss:./app/assets/builds/application.css --no-source-map --load-path=node_modules"
   }
   ```

## 8. Updating View Templates

1. **Replace Webpacker Helpers**:

   ```erb
   <%# Before %>
   <%= javascript_pack_tag 'application' %>
   <%= stylesheet_pack_tag 'application' %>
   
   <%# After %>
   <%= javascript_include_tag 'application', 'data-turbo-track': 'reload', defer: true %>
   <%= stylesheet_link_tag 'application', 'data-turbo-track': 'reload' %>
   ```

2. **Update Vue Component Mounting**:

   ```erb
   <%# Before %>
   <%= content_tag :div, '', 
         id: 'example-component', 
         data: { options: { prop1: 'value1' }.to_json } %>
   
   <%# After %>
   <%= content_tag :div, '', 
         data: { 
           vue_component: 'ExampleComponent',
           prop1: 'value1'
         } %>
   ```

## 9. Asset Handling

1. **Move Static Assets**:

   ```bash
   # Move image assets from app/javascript to app/assets
   mkdir -p app/assets/images
   cp -r app/javascript/images/* app/assets/images/
   ```

2. **Update Image References in CSS**:

   ```scss
   // Before
   background-image: url('~images/logo.png');
   
   // After
   background-image: url('logo.png');
   ```

3. **Update Image References in JavaScript**:

   ```javascript
   // Before
   import logo from '../images/logo.png'
   
   // After
   // Use asset_path in your views instead, or
   const logo = '/assets/logo.png'
   ```

## 10. Testing Your Setup

1. **Build your assets**:

   ```bash
   yarn build
   yarn build:css
   ```

2. **Start rails server**:

   ```bash
   bin/dev  # If you set up foreman in the jsbundling-rails install
   # or
   rails server
   ```

3. **Check for errors** in the browser console and server logs

## 11. Common Issues and Solutions

1. **Missing Assets**:
   - Check paths in `config/application.rb`
   - Verify asset precompilation is working
   - Look for path references in JavaScript and CSS

2. **JavaScript Errors**:
   - Check import paths
   - Ensure all dependencies are installed
   - Look for Webpacker-specific code that needs to be updated

3. **Vue Component Issues**:
   - Verify Vue is properly imported
   - Check component registration
   - Inspect mounting logic

4. **CSS Import Issues**:
   - Move SCSS imports to the main SCSS file
   - Check for Webpack-specific import syntax

## 12. Finalizing the Migration

1. **Clean up old files**:

   ```bash
   # Once everything is working
   rm -rf app/javascript/packs
   ```

2. **Update documentation**:
   - Document the new asset pipeline
   - Update README with build instructions
   - Note any changes to development workflow

3. **Commit the changes**:

   ```bash
   git add .
   git commit -m "Migrate from Webpacker to jsbundling-rails + Propshaft"
   ```

By following these steps, you should be able to successfully migrate your Rails + Vue.js application from Webpacker to jsbundling-rails with esbuild and Propshaft.
## Implementation Summary from Vulcan Migration

We have successfully migrated Vulcan from Webpacker to jsbundling-rails. Here's a summary of our approach:

### What We Did

1. **Replaced Gems**:
   - Removed Webpacker
   - Added jsbundling-rails and propshaft for asset management

2. **Set Up Build Configuration**:
   - Created esbuild.config.js for JavaScript bundling
   - Configured sass for CSS processing
   - Set up build scripts in package.json

3. **Migrated Entry Points**:
   - Created 14 new entry points in app/javascript/
   - Updated esbuild.config.js to include all entry points
   - Added conditional initialization to only mount Vue components when elements exist

4. **Updated Templates**:
   - Replaced javascript_pack_tag with javascript_include_tag
   - Added type="module" attribute to script tags
   - Removed unnecessary stylesheet_pack_tag references

5. **Fixed Component Imports**:
   - Updated all Vue component imports to use .vue extension
   - Fixed imports across nested components
   - Created a Bootstrap Vue shim for component compatibility

### Tools We Created

1. **Asset Pack Tag Scanner**:
   ```bash
   bundle exec rails migration:find_pack_tags
   ```
   This tool scans all templates for javascript_pack_tag, stylesheet_pack_tag, and other asset helpers, generating a migration inventory.

2. **Error Log Extractor**:
   ```bash
   bundle exec rails migration:log_errors
   ```
   This tool extracts and formats errors from the Rails log, making debugging easier.

### Lessons Learned

1. **Explicit File Extensions**:
   - Always include .vue extension in import statements
   - Be consistent with file extensions across the codebase

2. **Component Registration**:
   - Check case sensitivity in Vue component registration
   - Use consistent naming between templates and JavaScript

3. **Conditional Mounting**:
   - Always check if the target element exists before mounting Vue components
   - Use element ID consistency between templates and JavaScript

4. **Dependency Management**:
   - esbuild requires fewer configuration options than webpack
   - Plugin management is simpler with esbuild
   - File loading (images, fonts) requires specific configuration

The migration was completed with full feature parity, maintaining all functionality while simplifying the build process and improving build performance.
