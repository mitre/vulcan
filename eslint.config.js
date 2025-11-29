import antfu from '@antfu/eslint-config'

export default antfu({
  // Enable Vue and TypeScript
  vue: true,
  typescript: true,

  // Stylistic preferences
  stylistic: {
    indent: 2,
    quotes: 'single',
    semi: false,
  },

  // Ignore patterns
  ignores: [
    'docs/.vitepress/cache/**',
    'docs/.vitepress/dist/**',
    'node_modules/**',
    'app/assets/builds/**',
    'public/**',
    'vendor/**',
    'tmp/**',
    'log/**',
    'coverage/**',
  ],
},
// Custom rule overrides
{
  rules: {
    // Allow console for development (warn instead of error)
    'no-console': 'warn',

    // Vue-specific rules
    'vue/multi-word-component-names': 'off',
    'vue/require-default-prop': 'off',
    'vue/prop-name-casing': 'off',

    // TypeScript rules
    'ts/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
    'ts/explicit-function-return-type': 'off',
    'ts/no-explicit-any': 'warn',

    // Style preferences
    'style/max-len': 'off',
    'antfu/if-newline': 'off',

    // Allow some flexibility during migration
    'unused-imports/no-unused-vars': 'warn',
  },
},
// Special rules for Vue files
{
  files: ['**/*.vue'],
  rules: {
    // Allow template expressions
    'vue/no-v-html': 'warn',
  },
})
