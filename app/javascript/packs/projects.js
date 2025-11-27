import { createApp } from "vue";
import { createBootstrap } from "bootstrap-vue-next";
import Projects from "../components/projects/Projects.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Projects
    }
  });

  app.use(createBootstrap());
  app.mount("#Projects");
});
