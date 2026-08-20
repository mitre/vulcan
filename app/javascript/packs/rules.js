import { createVulcanApp } from "../lib/createVulcanApp";
import Rules from "../components/rules/Rules.vue";
import { createComponentEditorRouter } from "../router/componentEditor";

document.addEventListener("DOMContentLoaded", () => {
  createVulcanApp({
    el: "#Rules",
    componentName: "Rules",
    component: Rules,
    router: createComponentEditorRouter(),
  });
});
