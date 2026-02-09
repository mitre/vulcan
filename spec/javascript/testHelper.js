/**
 * Shared test helper — ONE place for test environment setup.
 *
 * Usage in test files:
 *   import { localVue } from '../../testHelper'       // or appropriate relative path
 *   import { localVue } from '@test/testHelper'       // with alias (configured in vitest.config.js)
 *
 * This eliminates duplicate BootstrapVue/IconsPlugin registration across 38+ test files.
 */
import { createLocalVue } from "@vue/test-utils";
import { BootstrapVue, IconsPlugin } from "bootstrap-vue";

const localVue = createLocalVue();
localVue.use(BootstrapVue);
localVue.use(IconsPlugin);

export { localVue };
