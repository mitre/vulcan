/**
 * Vitest Configuration for Vue 3 + Pinia
 *
 * Based on official @vue/test-utils configuration:
 * https://github.com/vuejs/test-utils/blob/main/vitest.config.ts
 */
import path from 'path'
import { fileURLToPath } from 'url'
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'app/javascript'),
      '~': path.resolve(__dirname, 'node_modules'),
      // Force ESM version of test-utils to avoid CJS/ESM interop issues
      '@vue/test-utils': path.resolve(__dirname, 'node_modules/@vue/test-utils/dist/vue-test-utils.esm-bundler.mjs'),
    },
    extensions: ['.vue', '.js', '.json', '.jsx', '.ts', '.tsx', '.mjs', '.node'],
    // Prevent duplicate Vue instances - critical for @vue/test-utils
    dedupe: ['vue'],
  },
  test: {
    css: false,
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    include: ['app/javascript/**/*.{test,spec}.{js,jsx,ts,tsx}'],
    exclude: ['node_modules', 'dist', 'app/assets'],
    // Inline Vue dependencies to ensure proper module resolution
    server: {
      deps: {
        inline: ['vue', '@vue/test-utils'],
      },
    },
  },
})
