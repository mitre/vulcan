/**
 * Monaco editor setup shared by every editor on the page.
 *
 * Loads the editor core, all editor features, and only the languages the
 * editors offer (Ruby, Markdown, YAML, JSON), using the tree-shakeable entry
 * points Monaco provides since 0.56. The TypeScript, CSS and HTML language
 * services are not loaded.
 *
 * Monaco runs tokenizing and diffing in web workers. The workers are built as
 * separate esbuild entry points (see esbuild.config.js) and served by Propshaft
 * from the same origin; Propshaft rewrites RAILS_ASSET_URL to the digested path
 * when it serves this bundle. They are created here with getWorker: given only
 * getWorkerUrl, Monaco wraps the URL in a blob: bootstrap, which the
 * Content-Security-Policy (script-src 'self') blocks.
 */
import * as monaco from "monaco-editor/editor";
import "monaco-editor/features/register.all";
import "monaco-editor/languages/definitions/ruby/register";
import "monaco-editor/languages/definitions/markdown/register";
import "monaco-editor/languages/definitions/yaml/register";
import "monaco-editor/languages/features/json/register";

// RAILS_ASSET_URL is not a runtime function: Propshaft replaces each call with
// the worker's digested URL when it serves the compiled bundle.
self.MonacoEnvironment = {
  getWorker(_moduleId, label) {
    const url =
      label === "json"
        ? RAILS_ASSET_URL("/monaco-json.worker.js")
        : RAILS_ASSET_URL("/monaco-editor.worker.js");
    return new Worker(url, { name: label });
  },
};

export { monaco };
