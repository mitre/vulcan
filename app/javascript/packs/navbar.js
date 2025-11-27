import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import Navbar from "../components/navbar/App.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Navbar
    }
  });

  registerComponents(app);
  app.mount("#navbar");
});
