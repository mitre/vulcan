<script>
import axios from "axios";

// This mixin is for a modal confirmation asking if a user really wants to release a component
export default {
  methods: {
    confirmComponentRelease: function () {
      if (!this.component.releasable) {
        return;
      }

      let body = this.$createElement("div", {
        domProps: {
          innerHTML:
            "<p>Are you sure you want to release this component?</p><p>This cannot be undone and will make the component publicly available within Vulcan.</p>",
        },
      });
      this.$bvModal
        .msgBoxConfirm(body, {
          title: "Release Component",
          size: "md",
          okTitle: "Release Component",
          okVariant: "success",
          cancelTitle: "Cancel",
          hideHeaderClose: false,
          centered: true,
        })
        .then((value) => {
          // confirm value was either null or false (clicked away or clicked cancel)
          if (!value) {
            return;
          }

          let payload = {
            component: {
              released: true,
            },
          };
          axios
            .patch(`/components/${this.component.id}`, payload)
            .then((response) => {
              this.alertOrNotifyResponse(response);
              this.$emit("projectUpdated");
            })
            .catch(this.alertOrNotifyResponse);
        })
        .catch((err) => {});
    },
  },
};
</script>
