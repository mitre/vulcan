const path = require("path");
const { sassPlugin } = require("esbuild-sass-plugin");
const vuePlugin = require("esbuild-plugin-vue3");

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
  rules: "app/javascript/packs/rules.js",
  security_requirements_guides: "app/javascript/packs/security_requirements_guides.js",
  stig: "app/javascript/packs/stig.js",
  stigs: "app/javascript/packs/stigs.js",
  users: "app/javascript/packs/users.js",
  new_project: "app/javascript/packs/new_project.js",
};

// Check if we're in watch mode
const watch = process.argv.includes("--watch");

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
      quietDeps: true, // Suppress deprecation warnings from dependencies
    }),
    vuePlugin(),
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
  format: "iife", // IIFE format for Vue 2 browser compatibility
  define: {
    "process.env.NODE_ENV": JSON.stringify(process.env.NODE_ENV || "development"),
    "process.env": JSON.stringify({ NODE_ENV: process.env.NODE_ENV || "development" }),
    __VUE_OPTIONS_API__: "true", // Enable Vue 3 Options API
    __VUE_PROD_DEVTOOLS__: "false", // Disable devtools in production
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: "false",
    __VUE_OPTIONS_COMPAT_MODE__: JSON.stringify({
      MODE: 2, // Vue 2 compat mode globally
      ATTR_FALSE_VALUE: false, // Suppress false attribute warnings
      CONFIG_WHITESPACE: false, // Suppress whitespace warnings
      WATCH_ARRAY: false, // Suppress watch array warnings
      INSTANCE_SET: false, // Suppress $set warnings
      OPTIONS_DESTROYED: false // Suppress destroyed→unmounted warnings
    }),
  },
  alias: {
    vue: "@vue/compat", // Use Vue 3 compat build for gradual migration
  },
  // Add inject option to automatically add needed polyfills
  inject: ["./node_modules/bootstrap/dist/js/bootstrap.js"],
  // Fix for CSS paths - allow both node_modules and relative paths
  resolveExtensions: [".js", ".json", ".vue", ".css", ".scss"],
  // Don't hash asset names in development for simpler Rails asset pipeline
  assetNames: "[name]",
  entryNames: "[name]",
};

// Add watch option only if in watch mode
if (watch) {
  buildOptions.watch = true;
}

require("esbuild")
  .build(buildOptions)
  .catch(() => process.exit(1));
