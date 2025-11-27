import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import Navbar from "../components/navbar/App.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Navbar
    }
  });

  app.use(createBootstrap());
  app.mount("#navbar");
});
