<template>
  <div>
    <a v-b-modal.find-replace-modal class="">Find &amp; Replace</a>
    <b-modal id="find-replace-modal" size="lg" title="Find & Replace">
      <b-form-group label="Find">
        <b-form-input v-model="fr.find" autocomplete="off" />
      </b-form-group>
      <b-form-group label="Replace">
        <b-form-input v-model="fr.replace" autocomplete="off" />
      </b-form-group>
      <div v-for="(rule, idx) in find_results" :key="idx">
        <b-card :title="formatRuleId(rule.rule_id)" class="mb-2">
          <b-card-text>
            <div
              v-for="(value, attr, index) in {
                Title: rule.title,
                'Vulnerability Discussion':
                  rule.disa_rule_descriptions_attributes[0].vuln_discussion,
                Check: rule.checks_attributes[0].content,
                Fix: rule.fixtext,
                'Vendor Comments': rule.vendor_comments,
              }"
              :key="index"
            >
              <FindAndReplaceResult :attr="attr" :value="value" />
            </div>
          </b-card-text>
        </b-card>
      </div>
      <template #modal-footer>
        <b-button variant="primary" :disabled="fr.find == ''" @click="find">Find</b-button>
        <b-button variant="primary" :disabled="fr.find == ''" @click="replace">
          Replace All
        </b-button>
      </template>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import FindAndReplaceResult from "./FindAndReplaceResult.vue";
export default {
  name: "FindAndReplace",
  components: { FindAndReplaceResult },
  props: {
    componentId: {
      type: Number,
      required: true,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
  },
  data: function () {
    return {
      fr: {
        find: "",
        replace: "",
      },
      find_results: [],
    };
  },
  methods: {
    find: function () {
      axios
        .post(`/components/${this.componentId}/find`, { find: this.fr.find })
        .then((response) => {
          this.find_results = response.data;
        });
    },
    replace: function () {
      axios.post(`/components/${this.componentId}/replace`, this.fr).then((response) => {
        console.log(response);
      });
    },
    formatRuleId: function (id) {
      return `${this.projectPrefix}-${id}`;
    },
  },
};
</script>

<style scoped></style>
