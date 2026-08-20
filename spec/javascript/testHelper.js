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
import { PiniaVuePlugin } from "pinia";

const localVue = createLocalVue();
localVue.use(PiniaVuePlugin);
localVue.use(BootstrapVue);
localVue.use(IconsPlugin);

async function flushPromises(wrapper) {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
}

/**
 * Run an action and capture the vulcan:toast event it dispatches (via the
 * useToast composable), or null if none fires. Flushes pending promise
 * chains so fire-and-forget handlers (.then/.catch pipelines) settle
 * before the listener is removed.
 */
async function captureVulcanToast(run, wrapper) {
  let detail = null;
  const listener = (event) => {
    detail = event.detail;
  };
  document.addEventListener("vulcan:toast", listener);
  try {
    await run();
    await flushPromises(wrapper);
  } finally {
    document.removeEventListener("vulcan:toast", listener);
  }
  return detail;
}

export { localVue, flushPromises, captureVulcanToast };
