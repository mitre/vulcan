<template>
  <div class="my-2">
    <b-input-group size="sm" class="mb-3">
      <b-input-group-prepend>
        <b-input-group-text class="rounded-0">Component Name</b-input-group-text>
      </b-input-group-prepend>
      <b-form-select
        id="componentName"
        v-model="componentName"
        class="form-select-sm"
        :options="uniqueComponentNames"
        @change="fetchRevisionHistory"
      />
    </b-input-group>
    <div v-if="loading" class="mt-3">
      <h6 class="m-3 text-center">Loading...</h6>
    </div>
    <div class="mt-3">
      <div v-for="(history, index) in revisionHistory.slice().reverse()" :key="`history-${index}`">
        <div v-if="history.component">
          <h6>
            {{ history.component.name }}
            {{
              history.component.version || history.component.release
                ? `(${[
                    history.component.version ? `Version ${history.component.version}` : "",
                    history.component.release ? `Release ${history.component.release}` : "",
                  ].join(", ")})`
                : ""
            }}
          </h6>
        </div>
        <div v-if="history.changes" class="pb-2">
          <div
            v-for="(rule_id, idx) in Object.keys(history.changes).sort()"
            :key="`history-${index}-rule-${idx}`"
            class="ml-3"
          >
            <p v-if="history.changes[rule_id].change === 'added'" class="mb-1">
              {{ history.diffComponent.prefix }}-{{ rule_id }} was added
            </p>
            <p v-if="history.changes[rule_id].change === 'removed'" class="mb-1">
              {{ history.baseComponent.prefix }}-{{ rule_id }} was removed
            </p>
            <p v-if="history.changes[rule_id].change === 'updated'" class="mb-1">
              {{ history.baseComponent.prefix }}-{{ rule_id }} was updated
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import MonacoEditor from "vue-monaco";
import AlertMixinVue from "../../mixins/AlertMixin.vue";

export default {
  name: "RevisionHistory",
  components: {},
  mixins: [AlertMixinVue],
  props: {
    project: {
      type: Object,
      required: true,
    },
    uniqueComponentNames: {
      type: Array,
      required: true,
    },
  },
  data: function () {
    return {
      componentName: "",
      revisionHistory: [],
      loading: false,
    };
  },
  methods: {
    fetchRevisionHistory: function () {
      if (this.componentName) {
        this.loading = true;
        axios
          .post(`/components/history`, {
            project_id: this.project.id,
            name: this.componentName,
          })
          .then((response) => {
            this.revisionHistory = response.data;
          })
          .catch(this.alertOrNotifyResponse)
          .then(() => {
            this.loading = false;
          });
      }
    },
  },
};
</script>

<style scoped>
.form-select-sm {
  height: 2rem;
}
</style>
