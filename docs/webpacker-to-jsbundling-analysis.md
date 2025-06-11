# Current Webpacker Configuration Analysis

## Webpacker Configuration Files

- `config/webpacker.yml` - Main configuration file
- `config/webpack/environment.js` - Environment setup with Vue.js config
- `config/webpack/loaders/vue.js` - Vue loader configuration
- `config/webpack/development.js` - Development environment
- `config/webpack/production.js` - Production environment
- `config/webpack/test.js` - Test environment
- `babel.config.js` - Babel configuration
- `postcss.config.js` - PostCSS configuration

## JavaScript Entry Points

The application has multiple entry points for different parts of the application:

```
app/javascript/packs/
  ├── application.js       # Main application entry point
  ├── login.js             # Login functionality
  ├── navbar.js            # Navigation bar
  ├── new_project.js       # New project form
  ├── project.js           # Project view
  ├── project_component.js # Project component
  ├── project_components.js# Project components
  ├── projects.js          # Projects list
  ├── rules.js             # Rules list/editor
  ├── security_requirements_guides.js
  ├── stig.js              # STIG view
  ├── stigs.js             # STIGs list
  ├── toaster.js           # Toast notifications
  └── users.js             # Users management
```

Each entry point initializes a Vue instance for a specific part of the application.

## Key Dependencies

- Vue.js 2.6.11
- Bootstrap 4.4.1
- Bootstrap Vue 2.13.0
- Monaco Editor 0.32.1
- Vue Turbolinks 2.1.0
- Axios 1.6.0
- Lodash 4.17.21

## Vue Component Structure

Vue components are organized by feature in:

```
app/javascript/components/
  ├── components/          # Component related features
  ├── memberships/         # Membership management
  ├── navbar/              # Navigation components
  ├── project/             # Project view components
  ├── projects/            # Projects list components
  ├── rules/               # Rule editing components
  │   └── forms/           # Rule form components
  ├── security_requirements_guides/
  ├── shared/              # Shared components
  ├── stigs/               # STIG components
  ├── toaster/             # Toast notification components
  └── users/               # User management components
```

## Vue Initialization Pattern

Each entry point follows a similar pattern:

```javascript
import TurbolinksAdapter from "vue-turbolinks";
import Vue from "vue";
import BootstrapVue from "bootstrap-vue";
import MainComponent from "../components/path/to/Component.vue";

Vue.use(TurbolinksAdapter);
Vue.use(BootstrapVue);

Vue.component("ComponentName", MainComponent);

document.addEventListener("turbolinks:load", () => {
  new Vue({
    el: "#ComponentMountPoint",
  });
});
```

## CSS/SCSS Structure

The main application styles are in `app/javascript/application.scss`, which imports Bootstrap and Bootstrap Vue styles.

Notable patterns:
- Bootstrap and Bootstrap Vue are imported at the root level
- Material Design Icons font path is customized
- Custom utility classes are defined
- Responsive typography using Bootstrap breakpoints

## Migration Considerations

1. **Multiple Entry Points**: Need to maintain multiple entry points or consolidate them
2. **Vue + Turbolinks**: Currently using vue-turbolinks adapter
3. **Bootstrap Vue**: Heavy use of Bootstrap Vue components
4. **Asset References**: Some components reference images and other assets
5. **Monaco Editor**: Custom editor integration
6. **CSS Imports**: Currently using the `~` syntax for node_modules imports