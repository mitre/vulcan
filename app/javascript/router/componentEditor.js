import Vue from "vue";
import VueRouter from "vue-router";

Vue.use(VueRouter);

export function createComponentEditorRouter() {
  return new VueRouter({
    mode: "hash",
    routes: [
      {
        path: "/",
        name: "editor-root",
        meta: { breadcrumb: "Editor" },
      },
      {
        path: "/rules/:ruleId",
        name: "rule",
        meta: { breadcrumb: "Rule" },
        props: true,
      },
    ],
  });
}
