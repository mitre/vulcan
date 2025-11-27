import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import Projects from "../components/projects/Projects.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Projects
    }
  });

  registerComponents(app);
  app.mount("#Projects");
});
