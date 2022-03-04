const { environment } = require("@rails/webpacker");
const { VueLoaderPlugin } = require("vue-loader");
const vue = require("./loaders/vue");
const MonacoWebpackPlugin = require("monaco-editor-webpack-plugin");

environment.plugins.prepend("VueLoaderPlugin", new VueLoaderPlugin());
environment.plugins.prepend(
  "MonacoWebpackPlugin",
  new MonacoWebpackPlugin({ languages: ["ruby"] })
);
environment.loaders.prepend("vue", vue);

const resolver = {
  resolve: {
    alias: {
      vue$: "vue/dist/vue.esm",
    },
  },
};
environment.config.merge(resolver);

module.exports = environment;
