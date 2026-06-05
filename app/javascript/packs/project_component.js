import { createVulcanApp } from "../lib/createVulcanApp";
import ProjectComponent from "../components/components/ProjectComponent.vue";
import linkify from "v-linkify";
import { createComponentEditorRouter } from "../router/componentEditor";

document.addEventListener("DOMContentLoaded", () => {
  createVulcanApp({
    el: "#projectcomponent",
    componentName: "Projectcomponent",
    component: ProjectComponent,
    directives: { linkified: linkify },
    router: createComponentEditorRouter(),
  });
});
