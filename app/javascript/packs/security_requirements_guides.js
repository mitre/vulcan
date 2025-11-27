import { createApp } from "vue";
import { registerComponents } from "../bootstrap-vue-next-components";
import SecurityRequirementsGuides from "../components/security_requirements_guides/SecurityRequirementsGuides.vue";

document.addEventListener("DOMContentLoaded", () => {
  const app = createApp({
    components: {
      Securityrequirementsguides: SecurityRequirementsGuides
    }
  });

  registerComponents(app);
  app.mount("#SecurityRequirementsGuides");
});
