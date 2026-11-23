const path = require("path");
const { sassPlugin } = require("esbuild-sass-plugin");
const vuePlugin = require("esbuild-vue");

// List all of our entry points with output names
const entryPoints = {
  application: "app/javascript/packs/application.js", // This imports application.scss
  "bootstrap-vue": "app/javascript/bootstrap-vue.scss",
  navbar: "app/javascript/packs/navbar.js",
  toaster: "app/javascript/packs/toaster.js",
  login: "app/javascript/packs/login.js",
  projects: "app/javascript/packs/projects.js",
  project: "app/javascript/packs/project.js",
  project_components: "app/javascript/packs/project_components.js",
  project_component: "app/javascript/packs/project_component.js",
  project_triage: "app/javascript/packs/project_triage.js",
  component_triage: "app/javascript/packs/component_triage.js",
  component_settings: "app/javascript/packs/component_settings.js",
  released_component: "app/javascript/packs/released_component.js",
  rules: "app/javascript/packs/rules.js",
  security_requirements_guides: "app/javascript/packs/security_requirements_guides.js",
  srg: "app/javascript/packs/srg.js",
  stig: "app/javascript/packs/stig.js",
  stigs: "app/javascript/packs/stigs.js",
  users: "app/javascript/packs/users.js",
  user_profile: "app/javascript/packs/user_profile.js",
  user_password: "app/javascript/packs/user_password.js",
  user_activity: "app/javascript/packs/user_activity.js",
  user_comments: "app/javascript/packs/user_comments.js",
  user_tokens: "app/javascript/packs/user_tokens.js",
};

// assets:precompile runs this build with RAILS_ENV=production (the Dockerfile
// and Heroku both set it). The Dockerfile leaves NODE_ENV unset, because yarn
// would then skip the devDependencies that build the assets, so NODE_ENV alone
// cannot mark a production build. Production builds are minified and define
// process.env.NODE_ENV as "production", which selects Vue's production mode.
const production = process.env.RAILS_ENV === "production" || process.env.NODE_ENV === "production";
const nodeEnv = production ? "production" : process.env.NODE_ENV || "development";

const buildOptions = {
  entryPoints,
  bundle: true,
  outdir: "app/assets/builds",
  absWorkingDir: path.resolve(__dirname),
  metafile: true, // Useful for debugging dependencies
  plugins: [
    sassPlugin({
      loadPaths: ["node_modules"],
      style: "expanded", // Use expanded style for better debugging
    }),
    vuePlugin({
      // esbuild-vue otherwise reads NODE_ENV itself, which the Docker build
      // leaves unset, and would compile single-file components in dev mode.
      production,
      enableDevtools: true, // Enable Vue devtools for development
      cssInline: true, // Extract CSS for better loading performance
      useFullVue: true, // Use full Vue build with template compiler
    }),
  ],
  loader: {
    ".png": "file",
    ".jpg": "file",
    ".svg": "file",
    ".woff": "file",
    ".woff2": "file",
    ".ttf": "file",
    ".eot": "file",
  },

  // Make files available at their expected paths with correct prefix
  publicPath: "/assets",
  sourcemap: true,
  minify: production,
  format: "iife", // IIFE format for Vue 2 browser compatibility
  define: {
    "process.env.NODE_ENV": JSON.stringify(nodeEnv),
    __VUE_OPTIONS_API__: "true", // Enable Vue Options API
    __VUE_PROD_DEVTOOLS__: "true", // Enable Vue devtools even in production
  },
  alias: {
    vue: "vue/dist/vue.esm.js", // Use the full build with template compiler
  },
  // Add inject option to automatically add needed polyfills
  inject: ["./node_modules/bootstrap/dist/js/bootstrap.js"],
  // Fix for CSS paths - allow both node_modules and relative paths
  resolveExtensions: [".js", ".json", ".vue", ".css", ".scss"],
  // Content-hashed asset names marked as already digested, so Propshaft
  // serves them under the same name the bundles reference (jsbundling-rails'
  // documented setting) instead of adding a second digest.
  assetNames: "[name]-[hash].digested",
};

// Monaco's web workers have no DOM, so they are built on their own: no
// injected bootstrap.js and no Vue or Sass plugins (Monaco's esbuild sample).
// app/javascript/utils/monaco.js points the editor at these files.
const monacoWorkerBuildOptions = {
  entryPoints: {
    "monaco-editor.worker": "node_modules/monaco-editor/esm/vs/editor/editor.worker.js",
    "monaco-json.worker":
      "node_modules/monaco-editor/esm/vs/languages/features/json/json.worker.js",
  },
  bundle: true,
  outdir: "app/assets/builds",
  absWorkingDir: path.resolve(__dirname),
  sourcemap: true,
  minify: production,
  format: "iife",
  define: {
    "process.env.NODE_ENV": JSON.stringify(nodeEnv),
  },
};

const esbuild = require("esbuild");

Promise.all([esbuild.build(buildOptions), esbuild.build(monacoWorkerBuildOptions)]).catch(() =>
  process.exit(1),
);
