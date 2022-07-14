<template>
  <div>
    <a v-b-modal.find-replace-modal class="">Find &amp; Replace</a>
    <b-modal id="find-replace-modal" size="xl" title="Find & Replace">
      <b-form-group label="Find">
        <b-form-input v-model="fr.find" autocomplete="off" />
      </b-form-group>
      <b-form-group label="Replace">
        <b-form-input v-model="fr.replace" autocomplete="off" />
      </b-form-group>
      <div v-for="[id, find_result] in Object.entries(find_results)" :key="id">
        <b-card :title="formatRuleId(find_result.rule_id)" class="mb-3">
          <b-card-text>
            <div v-for="(result, index) in find_result.results" :key="index">
              <FindAndReplaceResult
                :field="result.field"
                :value="result.value"
                :find="find_text"
                :replace="fr.replace"
                @replace_one="replace_one(id, result)"
              />
            </div>
          </b-card-text>
        </b-card>
      </div>
      <template #modal-footer>
        <b-button variant="primary" :disabled="fr.find == ''" @click="find">Find</b-button>
        <b-button variant="primary" :disabled="fr.find == ''" @click="replace_all">
          Replace All
        </b-button>
      </template>
    </b-modal>
  </div>
</template>

<script>
import _ from "lodash";
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
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
  components: { FindAndReplaceResult },
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
      fr: {
        find: "",
        replace: "",
      },
      find_text: "",
      find_results: [],
    };
  },
  methods: {
    find: function () {
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
        });
    },
    replace_one: function (rule_id, result) {
      const original_rule = this.rules.find((rule) => rule.id == rule_id);
      const new_value = result.value.replace(
        new RegExp("\\b" + this.find_text + "\\b"),
        this.fr.replace
      );
      _.set(original_rule, FIND_AND_REPLACE_FIELDS[result.field], new_value);

      const payload = {
        rule: {
          ...original_rule,
          audit_comment: "Find and Replace",
        },
      };
      axios
        .put(`/rules/${rule_id}`, payload)
        .then((response) => {
          this.saveRuleSuccess(response, rule_id);
        })
        .catch(this.alertOrNotifyResponse);
    },
    replace_all: function () {
      // axios.post(`/components/${this.componentId}/replace_all`, this.fr).then((response) => {
      //   // location.reload();
      // });
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
