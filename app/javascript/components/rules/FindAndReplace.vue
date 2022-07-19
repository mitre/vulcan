<template>
  <div>
    <a v-b-modal.find-replace-modal class="">Find &amp; Replace</a>
    <b-modal
      id="find-replace-modal"
      size="xl"
      title="Find & Replace"
      @show="resetModal"
      @hidden="resetModal"
    >
      <b-form-group label="Find">
        <b-form-input v-model="fr.find" autocomplete="off" />
      </b-form-group>
      <b-form-group label="Replace">
        <b-form-input
          v-model="fr.replace"
          :disabled="fr.find == '' || Object.keys(find_results).length == 0"
          autocomplete="off"
        />
      </b-form-group>
      <div
        v-for="[id, find_result] in Object.entries(find_results)"
        :key="`${find_results_ver}-${id}`"
      >
        <b-card :title="formatRuleId(find_result.rule_id)" class="mb-3">
          <b-card-text>
            <div v-for="(result, index) in find_result.results" :key="index">
              <FindAndReplaceResult
                :field="result.field"
                :value="result.value"
                :find="find_text"
                :replace="fr.replace"
                :disabled="loading"
                @replace_one="replace_one(id, result, $event, false)"
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
          :button-disabled="fr.find == '' || Object.keys(find_results).length == 0 || loading"
          @comment="replace_all($event)"
        />
      </template>
    </b-modal>
  </div>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import CommentModal from "../shared/CommentModal.vue";
import FindAndReplaceResult from "./FindAndReplaceResult.vue";

const FIND_AND_REPLACE_FIELDS = {
  Title: ["title"],
  "Vulnerability Discussion": ["disa_rule_descriptions_attributes", 0, "vuln_discussion"],
  Check: ["checks_attributes", 0, "content"],
  Fix: ["fixtext"],
  "Vendor Comments": ["vendor_comments"],
};

export default {
  name: "FindAndReplace",
  components: { CommentModal, FindAndReplaceResult },
  mixins: [AlertMixinVue],
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
  },
  data: function () {
    return {
      loading: false,
      fr: {
        find: "",
        replace: "",
      },
      find_text: "",
      find_results: {},
      find_results_ver: 0,
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
          this.find_results = {};
          response.data.forEach((rule) => {
            Object.entries(FIND_AND_REPLACE_FIELDS).forEach(([key, path]) => {
              const value = _.get(rule, path);
              if (value && value.toLowerCase().includes(this.find_text.toLowerCase())) {
                const result = { field: key, value: value };
                if (rule.id in this.find_results) {
                  this.find_results[rule.id].results.push(result);
                } else {
                  this.find_results[rule.id] = {
                    rule_id: rule.rule_id,
                    results: [result],
                  };
                }
              }
            });
          });
          this.find_results_ver += 1;
          this.loading = false;
        });
    },
    replace_one: function (rule_id, result, comment, stillLoading) {
      this.loading = true;
      const original_rule = this.rules.find((rule) => rule.id == rule_id);
      const new_value = result.value.replace(
        new RegExp("\\b" + this.find_text + "\\b"),
        this.fr.replace
      );
      console.log(rule_id);
      console.log(result.value);
      console.log(this.find_text);
      console.log(this.fr.replace);
      console.log(new_value);
      _.set(original_rule, FIND_AND_REPLACE_FIELDS[result.field], new_value);
      console.log(original_rule);

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
          if (!stillLoading) {
            this.find();
          }
        });
    },
    replace_all: function (comment) {
      this.loading = true;
      const promises = [];
      Object.values(this.find_results).forEach(function (find_results) {
        find_results.results.forEach(function (result) {
          promises.append(this.replace_one(find_results.rule_id, result, comment, true));
        });
      });
      Promise.all(promises).then(function () {
        this.find();
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
@media (min-width: 992px) .modal-xl {
  max-width: auto !important;
}

@media (min-width: 576px) .modal-dialog {
  max-width: auto !important;
}
</style>
