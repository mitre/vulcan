const path = require('path');
const { sassPlugin } = require('esbuild-sass-plugin');
const vuePlugin = require('esbuild-vue');

// List all of our entry points
const entryPoints = [
  'app/javascript/application.js',
  'app/javascript/application.scss',
  'app/javascript/navbar.js',
  'app/javascript/toaster.js',
  'app/javascript/login.js',
  'app/javascript/projects.js',
  'app/javascript/project.js',
  'app/javascript/project_components.js',
  'app/javascript/project_component.js',
  'app/javascript/rules.js',
  'app/javascript/security_requirements_guides.js',
  'app/javascript/stig.js',
  'app/javascript/stigs.js',
  'app/javascript/users.js',
  'app/javascript/new_project.js'
];

// Check if we're in watch mode
const watch = process.argv.includes('--watch');

const buildOptions = {
  entryPoints,
  bundle: true,
  outdir: 'app/assets/builds',
  absWorkingDir: path.resolve(__dirname),
  metafile: true, // Useful for debugging dependencies
  plugins: [
    sassPlugin({
      loadPaths: ['node_modules'],
      style: 'expanded' // Use expanded style for better debugging
    }),
    vuePlugin({
      enableDevtools: true, // Enable Vue devtools for development
      cssInline: true, // Extract CSS for better loading performance
      useFullVue: true // Use full Vue build with template compiler
    })
  ],
  loader: {
    '.png': 'file',
    '.jpg': 'file',
    '.svg': 'file',
    '.woff': 'file',
    '.woff2': 'file',
    '.ttf': 'file',
    '.eot': 'file',
  },
  
  // Make files available at their expected paths with correct prefix
  publicPath: '/assets',
  sourcemap: true,
  format: 'esm',
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'development'),
    '__VUE_OPTIONS_API__': 'true', // Enable Vue Options API
    '__VUE_PROD_DEVTOOLS__': 'true' // Enable Vue devtools even in production
  },
  alias: {
    'vue': 'vue/dist/vue.esm.js' // Use the full build with template compiler
  },
  // Add inject option to automatically add needed polyfills
  inject: [
    './node_modules/bootstrap/dist/js/bootstrap.js',
  ],
  // Fix for CSS paths - allow both node_modules and relative paths
  resolveExtensions: ['.js', '.json', '.vue', '.css', '.scss'],
  // Standard asset naming with content hash for proper caching
  assetNames: '[name]-[hash].[ext]',
};

// Add watch option only if in watch mode
if (watch) {
  buildOptions.watch = true;
}

require('esbuild').build(buildOptions).catch(() => process.exit(1));