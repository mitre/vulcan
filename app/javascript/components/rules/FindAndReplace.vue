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
      <div v-for="[id, result] in Object.entries(find_results)" :key="id">
        <b-card :title="formatRuleId(id)" class="mb-2">
          <b-card-text>
            <div v-for="(field, index) in result" :key="index">
              <FindAndReplaceResult :find="find_text" :attr="field.attr" :value="field.value" />
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
            Object.entries({
              Title: rule.title,
              "Vulnerability Discussion": rule.disa_rule_descriptions_attributes[0].vuln_discussion,
              Check: rule.checks_attributes[0].content,
              Fix: rule.fixtext,
              "Vendor Comments": rule.vendor_comments,
            }).forEach(([key, value]) => {
              if (value && value.toLowerCase().includes(this.find_text.toLowerCase())) {
                const result = { attr: key, value: value };
                if (rule.id in this.find_results) {
                  this.find_results[rule.id].push(result);
                } else {
                  this.find_results[rule.id] = [result];
                }
              }
            });
          });
        });
    },
    replace_all: function () {
      axios.post(`/components/${this.componentId}/replace_all`, this.fr).then((response) => {
        // location.reload();
      });
    },
    formatRuleId: function (id) {
      return `${this.projectPrefix}-${id}`;
    },
  },
};
</script>

<style scoped></style>
