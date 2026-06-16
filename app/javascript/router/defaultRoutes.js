import Vue from "vue";
import VueRouter from "vue-router";

Vue.use(VueRouter);

export function createDefaultRouter() {
  return new VueRouter({
    mode: "hash",
    routes: [{ path: "/", name: "root" }],
  });
}
