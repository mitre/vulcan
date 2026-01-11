import path from 'node:path'
import vue from '@vitejs/plugin-vue'
import IconsResolver from 'unplugin-icons/resolver'
import Icons from 'unplugin-icons/vite'
import Components from 'unplugin-vue-components/vite'
import { defineConfig } from 'vite'
import compression from 'vite-plugin-compression'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  define: {
    global: 'window',
  },
  plugins: [
    RubyPlugin(),
    vue(),
    // Auto-import Vue components
    Components({
      resolvers: [
        // Auto-import icons as components
        IconsResolver({
          prefix: 'I', // Icon components use I prefix: <IBiGithub />
        }),
      ],
      dts: 'app/javascript/components.d.ts', // TypeScript declarations
    }),
    // Icon plugin with auto-install
    Icons({
      autoInstall: true, // Automatically install icon sets when used
      compiler: 'vue3',
    }),
    // Gzip compression for production builds
    compression({
      algorithm: 'gzip',
      ext: '.gz',
      threshold: 1024, // Only compress files > 1KB
    }),
    // Brotli compression (better ratio, modern browsers)
    compression({
      algorithm: 'brotliCompress',
      ext: '.br',
      threshold: 1024,
    }),
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'app/javascript'),
      '@components': path.resolve(__dirname, 'app/javascript/components'),
      '@stores': path.resolve(__dirname, 'app/javascript/stores'),
      '@composables': path.resolve(__dirname, 'app/javascript/composables'),
      '@pages': path.resolve(__dirname, 'app/javascript/pages'),
      'jquery': 'jquery/dist/jquery.js',
    },
    extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue'],
  },
  optimizeDeps: {
    include: [
      'jquery',
      'lodash',
      'axios',
      'vue',
      'vue-router',
      'pinia',
      'bootstrap',
      '@popperjs/core',
      'fuse.js',
      'moment',
      'marked',
      'dompurify',
    ],
  },
  css: {
    preprocessorOptions: {
      scss: {
        // Don't add additionalData - application.scss handles imports
        quietDeps: true,
      },
    },
  },
  build: {
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-vue': ['vue', 'vue-router', 'pinia'],
          'vendor-ui': ['bootstrap', '@popperjs/core', 'bootstrap-vue-next'],
          'vendor-utils': ['lodash', 'axios', 'moment', 'fuse.js'],
        },
      },
    },
  },
})
