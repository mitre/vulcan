import { createVulcanApp } from "../lib/createVulcanApp";
import ComponentTriagePage from "../components/components/ComponentTriagePage.vue";
import linkify from "v-linkify";
import { createTriageRouter } from "../router/triagePage";

document.addEventListener("DOMContentLoaded", () => {
  createVulcanApp({
    el: "#componenttriage",
    componentName: "Componenttriage",
    component: ComponentTriagePage,
    directives: { linkified: linkify },
    router: createTriageRouter(),
  });
});
