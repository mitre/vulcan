import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({});
  app.use(createBootstrap());
  app.mount("#login");
});
