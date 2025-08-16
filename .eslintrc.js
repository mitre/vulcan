module.exports = {
  env: {
    browser: true,
    es6: true,
    node: true,
  },
  extends: ["plugin:vue/recommended", "prettier", "plugin:prettier/recommended"],
  ignorePatterns: [
    "docs/.vitepress/cache/**",
    "docs/.vitepress/dist/**",
    "node_modules/**",
    "app/assets/builds/**",
  ],
  rules: {
    "max-len": "off",
    "no-console": "warn",
    "no-return-await": "warn",
    "no-throw-literal": "warn",
    "vue/require-default-prop": "off",
    "vue/prop-name-casing": "off",
    "vue/multi-word-component-names": "off",
    "object-curly-spacing": "off",
    "lines-between-class-members": ["warn", "always", { exceptAfterSingleLine: true }],
    "padding-line-between-statements": [
      "warn",
      { blankLine: "always", prev: "function", next: "*" },
      { blankLine: "always", prev: "import", next: ["class", "function"] },
    ],
    "vue/html-self-closing": [
      "warn",
      {
        html: {
          void: "always",
        },
      },
    ],
  },
};
