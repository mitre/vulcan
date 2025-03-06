const path = require('path');
const { sassPlugin } = require('esbuild-sass-plugin');
const vuePlugin = require('esbuild-vue');

// List all of our entry points
const entryPoints = [
  'app/javascript/application.js',
  'app/javascript/application.scss',
  'app/javascript/navbar.js',
  'app/javascript/toaster.js',
  // We'll gradually add more entry points as we migrate them
];

// Check if we're in watch mode
const watch = process.argv.includes('--watch');

require('esbuild').build({
  entryPoints,
  bundle: true,
  outdir: 'app/assets/builds',
  absWorkingDir: path.resolve(__dirname),
  publicPath: '/assets',
  metafile: true, // Useful for debugging dependencies
  plugins: [
    sassPlugin({
      loadPaths: ['node_modules']
    }),
    vuePlugin()
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
  sourcemap: true,
  format: 'esm',
  define: {
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'development')
  },
  watch: watch,
}).catch(() => process.exit(1));