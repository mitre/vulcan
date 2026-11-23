import { describe, it, expect } from "vitest";
import { isVue2 } from "vue-demi";

// vue-demi picks its Vue 2 or Vue 3 build in its own install script, the one
// third-party install script .yarnrc.yml and package.json's dependenciesMeta
// allow. If that script does not run, vue-demi stays on its Vue 3 build and
// Pinia and the asset build break.
describe("vue-demi", () => {
  it("is installed for Vue 2", () => {
    expect(isVue2).toBe(true);
  });
});
