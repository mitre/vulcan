import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import vue from '@vitejs/plugin-vue'
import compression from 'vite-plugin-compression'
import path from 'path'

export default defineConfig({
  define: {
    global: 'window',
  },
  plugins: [
    RubyPlugin(),
    vue(),
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
      'jquery': 'jquery/dist/jquery.js'
    },
    extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue']
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
      'dompurify'
    ]
  },
  css: {
    preprocessorOptions: {
      scss: {
        // Don't add additionalData - application.scss handles imports
        quietDeps: true
      }
    }
  },
  build: {
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor-vue': ['vue', 'vue-router', 'pinia'],
          'vendor-ui': ['bootstrap', '@popperjs/core', 'bootstrap-vue-next'],
          'vendor-utils': ['lodash', 'axios', 'moment', 'fuse.js']
        }
      }
    }
  }
})
