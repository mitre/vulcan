<template>
  <div>
    <b-modal
      id="upload-srg-modal"
      v-model="modalShow"
      size="lg"
      title="Upload an SRG"
      @hidden="clearFile()"
    >
      <b-form-file
        v-model="file"
        placeholder="Choose or drop an SRG XML here..."
        drop-placeholder="Drop SRG XML here..."
        accept="text/xml, application/xml"
      />
      <template #modal-footer>
        <div class="row w-100">
          <div class="col-8 pl-0">
            <p class="text-left">Selected file: {{ file ? file.name : "No file selected" }}</p>
          </div>
          <div class="col-4 pr-0">
            <b-button
              variant="primary"
              class="float-right"
              :disabled="!file || loading"
              @click="submitUpload()"
            >
              {{ loading ? "Loading..." : "Upload" }}
            </b-button>
            <b-button variant="primary" class="float-right mr-2" @click="clearFile()">
              Clear
            </b-button>
          </div>
        </div>
      </template>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
// Needed for axios headers and authenticity token on SRG upload.
import FormMixinVue from "../../mixins/FormMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "SecurityRequirementsGuidesUpload",
  mixins: [FormMixinVue, AlertMixinVue],
  props: {
    value: {
      type: Boolean,
      required: true,
    },
  },
  data: function () {
    return {
      file: null,
      loading: false,
    };
  },
  computed: {
    modalShow: {
      get: function () {
        return this.value;
      },
      set: function (value) {
        this.$emit("input", value);
      },
    },
  },
  methods: {
    clearFile: function () {
      this.file = null;
    },
    submitUpload: function () {
      this.loading = true;
      let formData = new FormData();
      formData.append("file", this.file);

      axios
        .post("/srgs", formData, {
          headers: {
            "Content-Type": "multipart/form-data",
          },
        })
        .then(this.srgUploadSuccess)
        .catch(this.srgUploadError)
        .finally(this.completeLoading);
    },
    completeLoading: function () {
      this.loading = false;
    },
    srgUploadError: function (response) {
      this.alertOrNotifyResponse(response.response);
    },
    srgUploadSuccess: function (response) {
      this.modalShow = false;
      this.alertOrNotifyResponse(response);
      this.$emit("uploaded");
    },
  },
};
</script>

<style scoped></style>
