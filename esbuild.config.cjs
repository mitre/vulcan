const path = require("path");
const { sassPlugin } = require("esbuild-sass-plugin");
const vuePlugin = require("esbuild-plugin-vue3");

// List all of our entry points with output names
const entryPoints = {
  application: "app/javascript/entrypoints/application.ts", // Main SPA entry point
  "bootstrap-vue": "app/javascript/bootstrap-vue.scss",
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
    ".ts": "ts",
    ".tsx": "tsx",
  },

  // Make files available at their expected paths with correct prefix
  publicPath: "/assets",
  sourcemap: true,
  format: "iife", // IIFE format for browser compatibility
  define: {
    "process.env.NODE_ENV": JSON.stringify(process.env.NODE_ENV || "development"),
    "process.env": JSON.stringify({ NODE_ENV: process.env.NODE_ENV || "development" }),
    __VUE_OPTIONS_API__: "true", // Enable Vue 3 Options API
    __VUE_PROD_DEVTOOLS__: "false", // Disable devtools in production
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: "false",
  },
  alias: {
    vue: "vue", // Native Vue 3
    "@": path.resolve(__dirname, "app/javascript"),
  },
  // Add inject option to automatically add needed polyfills
  inject: ["./node_modules/bootstrap/dist/js/bootstrap.js"],
  // Fix for CSS paths - allow both node_modules and relative paths
  resolveExtensions: [".ts", ".tsx", ".js", ".jsx", ".json", ".vue", ".css", ".scss"],
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
