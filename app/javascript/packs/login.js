import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";

// Import Bootstrap and BootstrapVueNext styles
import "bootstrap/dist/css/bootstrap.css";
import "bootstrap-vue-next/dist/bootstrap-vue-next.css";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({});
  app.use(createBootstrap());
  app.mount("#login");
});
