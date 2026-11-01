import { expect, test } from "@playwright/test";
import { resolveTarget } from "../.vitepress/target.mjs";

const { api } = resolveTarget();

test.describe("API playground", () => {
  test("prefills the placeholder personal access token", async ({ page }) => {
    // Only builds read outside a running instance prefill a token; in-app the
    // reader's session authenticates reads.
    test.skip(!api.prefillToken, "this documentation target prefills no token");

    await page.goto("api/operations/getProject");

    await expect(page.locator('input[name="tokenAuth"]')).toHaveValue(api.prefillToken);
  });
});
