import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue2'
import path from 'node:path'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      // Critical: Vue Test Utils uses CJS, Vitest uses ESM
      vue: 'vue/dist/vue.runtime.common.js',
      '@': path.resolve(__dirname, 'app/javascript')
    },
    extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue']
  },
  css: {
    // Skip PostCSS processing in tests (postcss-import etc. are not installed as devDeps)
    postcss: {}
  },
  test: {
    globals: true,
    environment: 'jsdom',
    include: ['spec/javascript/**/*.spec.js'],
    setupFiles: ['./spec/javascript/setup.js']
  }
})
