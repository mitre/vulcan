const { environment } = require("@rails/webpacker");
const { VueLoaderPlugin } = require("vue-loader");
const vue = require("./loaders/vue");

environment.plugins.prepend("VueLoaderPlugin", new VueLoaderPlugin());
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
