import Vue from "vue";
import VueRouter from "vue-router";

Vue.use(VueRouter);

export function createTriageRouter() {
  return new VueRouter({
    mode: "hash",
    routes: [
      {
        path: "/",
        name: "triage-root",
        meta: { breadcrumb: "Triage" },
      },
      {
        path: "/comments/:commentId",
        name: "comment",
        meta: { breadcrumb: "Comment" },
        props: true,
      },
    ],
  });
}
