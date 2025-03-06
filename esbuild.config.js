const path = require('path');
const { sassPlugin } = require('esbuild-sass-plugin');

require('esbuild').build({
  entryPoints: [
    'app/javascript/application.js',
    'app/javascript/application.scss'
  ],
  bundle: true,
  outdir: 'app/assets/builds',
  absWorkingDir: path.resolve(__dirname),
  publicPath: '/assets',
  plugins: [
    sassPlugin({
      loadPaths: ['node_modules']
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
    '.vue': 'file' // Temporary setting - we'll need a proper Vue plugin
  },
  sourcemap: true,
  format: 'esm',
}).catch(() => process.exit(1));