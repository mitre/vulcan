<template>
  <div class="my-1">
    <b-row class="my-1">
      <b-col md="2">
        <div class="p-2">
          <h6>Compare Components:</h6>
        </div>
      </b-col>
      <b-col md="10">
        <b-input-group size="sm" class="mb-2">
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Base</b-input-group-text>
          </b-input-group-prepend>
          <b-form-select
            id="baseComponent"
            v-model="baseComponent"
            class="form-select-sm"
            @change="updateCompareList"
          >
            <option
              v-for="(selectOption, indexOpt) in project.components"
              :key="indexOpt"
              :value="selectOption"
            >
              {{ selectOption.name }}
              {{
                selectOption.version || selectOption.release
                  ? `(${[
                      selectOption.version ? `Version ${selectOption.version}` : "",
                      selectOption.release ? `Release ${selectOption.release}` : "",
                    ].join(", ")})`
                  : ""
              }}
            </option>
          </b-form-select>
          <b-input-group-prepend>
            <b-input-group-text class="rounded-0">Compare</b-input-group-text>
          </b-input-group-prepend>
          <b-form-select
            id="diffComponent"
            v-model="diffComponent"
            class="form-select-sm"
            :disabled="!baseComponent"
            @change="compareComponents"
          >
            <option
              v-for="(selectOption, indexOpt) in compareList"
              :key="indexOpt"
              :value="selectOption"
            >
              {{ selectOption.name }}
              {{
                selectOption.version || selectOption.release
                  ? `(${[
                      selectOption.version ? `Version ${selectOption.version}` : "",
                      selectOption.release ? `Release ${selectOption.release}` : "",
                    ].join(", ")})`
                  : ""
              }}
              {{ selectOption.project_name && `- ${selectOption.project_name}` }}
            </option>
          </b-form-select>
        </b-input-group>
        <div v-if="revisionHistory" class="my-2">
          <p v-for="(rule_id, idx) in revisionHistory.added" :key="idx" class="mb-1">
            {{ diffComponent.prefix }}-{{ rule_id }} was added
          </p>
          <p v-for="(rule_id, idx) in revisionHistory.removed" :key="idx" class="mb-1">
            {{ baseComponent.prefix }}-{{ rule_id }} was removed
          </p>
          <p v-for="(rule_id, idx) in revisionHistory.updated" :key="idx" class="mb-1">
            {{ baseComponent.prefix }}-{{ rule_id }} was updated
          </p>
        </div>
      </b-col>
    </b-row>
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
  },
  data: function () {
    return {
      baseComponent: null,
      diffComponent: null,
      compareList: [],
      revisionHistory: {},
    };
  },
  methods: {
    updateCompareList: function () {
      if (this.baseComponent) {
        axios
          .get(`/components/${this.baseComponent.id}/based_on_same_srg`)
          .then((response) => {
            this.compareList = response.data;
          })
          .catch(this.alertOrNotifyResponse);
      }
    },
    compareComponents: function () {
      if (
        this.baseComponent &&
        this.diffComponent &&
        this.baseComponent.id !== this.diffComponent.id
      ) {
        axios
          .get(`/components/${this.baseComponent.id}/revision/${this.diffComponent.id}`)
          .then((response) => {
            this.revisionHistory = response.data;
          })
          .catch(this.alertOrNotifyResponse);
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
