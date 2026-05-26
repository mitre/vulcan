<script>
// DEPRECATED: baseApi.js now sets CSRF + Accept headers at import time.
// FormMixin is still needed because esbuild creates separate bundles per
// pack file — each pack gets its own axios singleton, so the baseApi
// header setup in one pack doesn't affect another. FormMixin re-applies
// the headers when a component mounts inside a different pack.
// See: app/javascript/api/baseApi.js for the primary CSRF setup.
import api from "../api/baseApi";

export default {
  computed: {
    authenticityToken: function () {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
  mounted: function () {
    api.defaults.headers.common["X-CSRF-Token"] = this.authenticityToken;
    api.defaults.headers.common["Accept"] = "application/json";
  },
};
</script>
