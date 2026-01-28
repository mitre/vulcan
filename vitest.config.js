import { defineConfig } from 'vitest/config'
import { createVuePlugin } from 'vite-plugin-vue2'
import path from 'path'

export default defineConfig({
  plugins: [createVuePlugin()],
  resolve: {
    alias: {
      // Critical: Vue Test Utils uses CJS, Vitest uses ESM
      vue: 'vue/dist/vue.runtime.common.js',
      '@': path.resolve(__dirname, 'app/javascript')
    },
    extensions: ['.mjs', '.js', '.ts', '.jsx', '.tsx', '.json', '.vue']
  },
  test: {
    globals: true,
    environment: 'jsdom',
    include: ['spec/javascript/**/*.spec.js'],
    setupFiles: ['./spec/javascript/setup.js']
  }
})
