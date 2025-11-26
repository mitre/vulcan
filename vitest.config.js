import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue2'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'app/javascript'),
      '~': path.resolve(__dirname, 'node_modules')
    },
    extensions: ['.mjs', '.js', '.jsx', '.json', '.vue']
  },
  test: {
    css: false,
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.js'],
    include: ['app/javascript/**/*.{test,spec}.{js,jsx}'],
    exclude: ['node_modules', 'dist', 'app/assets']
  }
})
