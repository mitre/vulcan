<script>
import api from "../api/baseApi";

export default {
  computed: {
    // Authenticity Token for forms
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
