<template>
  <div>
    <b-modal
      id="upload-srg-modal"
      v-model="modalShow"
      size="lg"
      :title="`Upload an ${post_path ? 'STIG' : 'SRG'}`"
      @hidden="clearFile()"
    >
      <b-form-file
        v-model="file"
        :placeholder="`Choose or drop an ${post_path ? 'STIG' : 'SRG'} XML here...`"
        :drop-placeholder="`Drop ${post_path ? 'STIG' : 'SRG'} XML here...`"
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
import { uploadBenchmark } from "../../api/projectsApi";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "BenchmarkUpload",
  // AlertMixin migrates in 0re.9 (useToast). FormMixin was a dead import —
  // authenticityToken was never consumed; CSRF is handled by baseApi hooks.
  mixins: [AlertMixinVue],
  props: {
    value: {
      type: Boolean,
      required: true,
    },
    post_path: {
      type: String,
      default: null,
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
      const path = this.post_path ? this.post_path : "/srgs";
      uploadBenchmark(path, formData)
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
