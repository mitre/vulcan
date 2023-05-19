<template>
  <div>
    <b-button v-b-modal.find-replace-modal class="w-100">Find &amp; Replace</b-button>
    <b-modal
      id="find-replace-modal"
      size="xl"
      title="Find & Replace"
      @show="resetModal"
      @hidden="resetModal"
    >
      <b-form-group label="Find">
        <div class="find-input-wrapper">
          <b-form-input v-model="fr.find" autocomplete="off" />
          <label class="match-case-toggle">
            <b-form-checkbox v-model="fr.matchCase" />
            Match Case
          </label>
        </div>
      </b-form-group>
      <b-form-group label="Replace">
        <b-form-input
          v-model="fr.replace"
          :disabled="fr.find == '' || Object.keys(find_results).length == 0"
          autocomplete="off"
        />
      </b-form-group>
      <span v-if="find_results_ver">
        <small v-if="total_results_match">
          {{ total_results_match }} results in {{ total_results_control }} controls
        </small>
        <small v-else>No results found.</small>
      </span>
      <hr v-if="!Object.keys(find_results).length == 0" />
      <div
        v-if="!Object.keys(find_results).length == 0"
        class="d-flex justify-content-end align-items-center"
      >
        <b-button variant="primary" :disabled="fr.find == '' || loading" class="mr-4" @click="find"
          >Find</b-button
        >
        <CommentModal
          v-if="!readOnly"
          title="Replace All"
          message="Provide a comment that summarizes your changes to these controls."
          :require-non-empty="false"
          button-text="Replace All"
          button-variant="primary"
          :button-disabled="fr.find == '' || Object.keys(find_results).length == 0 || loading"
          @comment="replace_all($event)"
        />
      </div>
      <hr v-if="!Object.keys(find_results).length == 0" />
      <div
        v-for="[id, find_result] in Object.entries(find_results)"
        :key="`${find_results_ver}-${id}`"
      >
        <b-card :title="formatRuleId(find_result.rule_id)" class="mb-3">
          <b-card-text>
            <div v-for="(result, index) in find_result.results" :key="index">
              <FindAndReplaceResult
                :field="result.field"
                :segments="result.segments"
                :replace="fr.replace"
                :disabled="loading || readOnly"
                @replace_one="replace_one(id, result, $event)"
              />
            </div>
          </b-card-text>
        </b-card>
      </div>
      <template #modal-footer>
        <b-button variant="primary" :disabled="fr.find == '' || loading" @click="find"
          >Find</b-button
        >
        <CommentModal
          title="Replace All"
          message="Provide a comment that summarizes your changes to these controls."
          :require-non-empty="false"
          button-text="Replace All"
          button-variant="primary"
          :button-disabled="
            readOnly || fr.find == '' || Object.keys(find_results).length == 0 || loading
          "
          @comment="replace_all($event)"
        />
      </template>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FindAndReplaceMixinVue from "../../mixins/FindAndReplaceMixin.vue";
import CommentModal from "../shared/CommentModal.vue";
import FindAndReplaceResult from "./FindAndReplaceResult.vue";

export default {
  name: "FindAndReplace",
  components: { CommentModal, FindAndReplaceResult },
  mixins: [AlertMixinVue, FindAndReplaceMixinVue],
  props: {
    componentId: {
      type: Number,
      required: true,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data: function () {
    return {
      loading: false,
      fr: {
        find: "",
        replace: "",
        matchCase: false,
      },
      find_text: "",
      find_results: {},
      find_results_ver: 0,
      total_results_match: 0,
      total_results_control: 0,
    };
  },
  methods: {
    resetModal: function () {
      this.loading = false;
      this.fr = {
        find: "",
        replace: "",
      };
      this.find_text = "";
      this.find_results = {};
      this.find_results_ver = 0;
    },
    find: function () {
      this.loading = true;
      this.find_text = this.fr.find;
      axios
        .post(`/components/${this.componentId}/find`, { find: this.find_text })
        .then((response) => {
          this.find_results = this.groupFindResults(
            response.data,
            this.find_text,
            this.fr.matchCase
          );
          this.find_results_ver += 1;
          this.countTotalResults();
          this.loading = false;
        });
    },
    countTotalResults: function () {
      const resultValues = Object.values(this.find_results);
      this.total_results_control = resultValues.length;
      this.total_results_match = resultValues.reduce((total, obj) => {
        return (
          total +
          obj.results.reduce((count, result) => {
            return (
              count +
              result.segments.filter((segment) => segment.text.length > 0 && segment.highlighted)
                .length
            );
          }, 0)
        );
      }, 0);
    },
    replace_one: function (rule_id, result, comment) {
      this.loading = true;
      const original_rule = this.rules.find((rule) => rule.id == rule_id);
      this.replaceTextInRule(original_rule, result.field, result.segments, this.fr.replace);
      const payload = {
        rule: {
          ...original_rule,
          audit_comment: comment,
        },
      };
      return axios
        .put(`/rules/${rule_id}`, payload)
        .then((response) => {
          this.saveRuleSuccess(response, rule_id);
        })
        .catch(this.alertOrNotifyResponse)
        .then(() => {
          this.find();
        });
    },
    replace_all: function (comment) {
      const self = this;
      this.loading = true;
      const promises = [];
      Object.entries(this.find_results).forEach(function ([rule_id, find_results]) {
        const original_rule = self.rules.find((rule) => rule.id == rule_id);
        find_results.results.forEach(function (result) {
          self.replaceTextInRule(original_rule, result.field, result.segments, self.fr.replace);
        });
        const payload = {
          rule: {
            ...original_rule,
            audit_comment: comment,
          },
        };
        promises.push(
          axios
            .put(`/rules/${rule_id}`, payload)
            .then((response) => {
              self.saveRuleSuccess(response, rule_id);
            })
            .catch(self.alertOrNotifyResponse)
        );
      });
      Promise.all(promises).then(function () {
        self.find();
      });
    },
    saveRuleSuccess: function (response, rule_id) {
      this.alertOrNotifyResponse(response);
      this.$root.$emit("refresh:rule", rule_id);
    },
    formatRuleId: function (id) {
      return `${this.projectPrefix}-${id}`;
    },
  },
};
</script>

<style scoped>
.find-input-wrapper {
  position: relative;
}

.match-case-toggle {
  position: absolute;
  top: 50%;
  right: 0;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  margin-right: 10px;
  font-size: 12px;
  cursor: pointer;
}

@media (min-width: 992px) {
  .modal-xl {
    max-width: auto !important;
  }
}

@media (min-width: 576px) {
  .modal-dialog {
    max-width: auto !important;
  }
}
</style>
