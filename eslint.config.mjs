import { defineConfig, globalIgnores } from "eslint/config";
import pluginVue from "eslint-plugin-vue";
import eslintConfigPrettier from "eslint-config-prettier/flat";
import eslintPluginPrettierRecommended from "eslint-plugin-prettier/recommended";
import globals from "globals";
import commentTracker from "./eslint-rules/comment-tracker.js";

export default defineConfig([
  globalIgnores([
    "docs/.vitepress/cache/**",
    "docs/.vitepress/dist/**",
    "node_modules/**",
    "app/assets/builds/**",
  ]),

  // The application is Vue 2: in eslint-plugin-vue 10 the Vue 2 rule set is
  // "vue2-recommended" ("recommended" is now Vue 3).
  ...pluginVue.configs["flat/vue2-recommended"],
  eslintConfigPrettier,
  eslintPluginPrettierRecommended,

  {
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
    plugins: {
      // Project rules that live in this repository.
      vulcan: {
        rules: {
          "comment-tracker": commentTracker,
        },
      },
    },
    rules: {
      "max-len": "off",
      "no-console": "warn",
      "no-return-await": "warn",
      "no-throw-literal": "warn",
      "vulcan/comment-tracker": "error",
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
  },
]);
