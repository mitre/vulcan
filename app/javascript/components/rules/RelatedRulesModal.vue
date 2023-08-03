<!-- eslint-disable vue/no-v-html -->
<template>
  <div>
    <b-button
      v-b-modal.related-rules-modal
      v-b-tooltip.hover.html
      variant="info"
      title="Rules in other components or STIGs that have the same SRG ID"
    >
      View Related Rules
    </b-button>
    <b-modal
      id="related-rules-modal"
      ref="modal"
      :title="`Rules Related to ${ruleStigId}//${rule.version}`"
      class="responsive"
      centered
      ok-only
      size="xl"
      @show="resetModal"
    >
      <!-- RESET FILTERS -->
      <b-link class="h6 float-right" @click="resetFilters">Reset Filters</b-link>

      <!-- FILTER RESULTS BY STIG / COMPONENT -->
      <b-form-group label="Filter results by STIG / Vulcan Component" label-class="h6">
        <div class="row mb-2">
          <b-form-checkbox
            v-model="stigsAndComponents"
            :disabled="stigsAndComponents"
            class="ml-3 mr-4"
            switch
            @change="setStigAndComponentFilter('all')"
          >
            STIGs & Components
          </b-form-checkbox>
          <b-form-checkbox
            v-model="stigResultsOnly"
            :disabled="!stigsAndComponents && stigResultsOnly"
            class="mr-4"
            switch
            @change="setStigAndComponentFilter('stig')"
          >
            STIGs Only
          </b-form-checkbox>
          <b-form-checkbox
            v-model="componentResultsOnly"
            :disabled="!stigsAndComponents && componentResultsOnly"
            class="ml-md-3 ml-lg-0"
            switch
            @change="setStigAndComponentFilter('component')"
          >
            Components Only
          </b-form-checkbox>
        </div>
        <vue-simple-suggest
          :key="rule.id"
          v-model="selectedParent"
          :list="filteredParents"
          display-attribute="displayed"
          value-attribute="displayed"
          placeholder="Search STIG/Component by name ..."
          :filter-by-query="true"
          :min-length="0"
          :max-suggestions="0"
          :number="0"
        />
        <small class="text-info">
          {{ results }} Related Rules {{ selectedParent ? `in ${selectedParent}` : "" }}
        </small>
      </b-form-group>

      <!-- FILTER RESULTS BY FIELDS  & SEARCH KEYWORD -->
      <div class="row">
        <div class="col-6">
          <b-form-group>
            <template #label>
              <h6>Fields to include</h6>
              <b-form-checkbox
                v-model="allFieldsSelected"
                :indeterminate="indeterminate"
                aria-describedby="control-fields"
                aria-controls="control-fields"
                class="mt-1"
                :disabled="allFieldsSelected"
                switch
                @change="toggleAllFields"
              >
                Include All
              </b-form-checkbox>
            </template>
            <template #default="{ ariaDescribedby }">
              <div class="d-flex flex-wrap ml-3">
                <b-form-checkbox
                  v-for="option in controlFields"
                  :key="option"
                  v-model="fields"
                  :value="option"
                  :aria-describedby="ariaDescribedby"
                  :name="ariaDescribedby"
                  class="mb-lg-1 mr-4"
                  aria-label="Individual control fields"
                  :disabled="fields.length == 1 && fields.includes(option)"
                  switch
                >
                  {{ option }}
                </b-form-checkbox>
              </div>
            </template>
          </b-form-group>
        </div>
        <div class="col-6">
          <h6>Search</h6>
          <div class="input-group">
            <div class="input-group-prepend">
              <div class="input-group-text">
                <i class="mdi mdi-magnify" aria-hidden="true" />
              </div>
            </div>
            <input
              id="keywordSearch"
              v-model="keywordSearch"
              type="text"
              class="form-control"
              placeholder="Search keyword in results"
            />
          </div>
        </div>
      </div>
      <div class="d-flex justify-content-end">
        <b-button class="mr-3" @click="toggleAllCollapses(false)"> Collapse All </b-button>
        <b-button class="mr-3" @click="toggleAllCollapses(true)"> Open All </b-button>
      </div>
      <br />

      <!-- RELATED RULES RESULTS GROUPED BY STIG/COMPONENT NAME -->
      <div v-for="parent in Object.keys(filteredGroupedRules)" :key="parent" class="col">
        <b-card-header class="bg-secondary text-white mb-4">
          <h3>
            {{ parent }}
            <b-badge class="float-right" variant="light">
              {{ filteredGroupedRules[parent].length }}
            </b-badge>
          </h3>
        </b-card-header>
        <b-card-group
          v-for="relatedRule in filteredGroupedRules[parent]"
          :key="relatedRule.name"
          class="mb-2"
          deck
        >
          <b-card no-body class="mb-2 h-100">
            <b-card-header
              header-tag="header"
              class="bg-light text-info clickable"
              @click="relatedRule.show = !relatedRule.show"
            >
              {{ relatedRule.name }}
              <i class="mdi mdi-collapse-all float-right" />
            </b-card-header>
            <b-collapse :id="relatedRule.name" v-model="relatedRule.show">
              <b-card-body>
                <div class="row p-2 bg-light">
                  <b-card-text
                    v-if="fields.includes('Vulnerability Discussion')"
                    class="col-md-12"
                    :class="dynamicDisplayFieldClass"
                  >
                    <h5>Vulnerability Discussion</h5>
                    <b-button
                      class="mb-2"
                      size="sm"
                      @click="
                        copyDiscussionToRule(
                          $root,
                          relatedRule.disa_rule_descriptions_attributes[0].vuln_discussion
                        )
                      "
                    >
                      Copy to {{ ruleStigId }}
                    </b-button>
                    <div
                      class="border p-2 overflow-auto"
                      style="background: #e9ecef; opacity: 1; height: 375px; line-height: 1.5"
                      v-html="
                        formatAndHighlightSearchWord(
                          relatedRule.disa_rule_descriptions_attributes[0].vuln_discussion
                        )
                      "
                    />
                  </b-card-text>
                  <b-card-text
                    v-if="fields.includes('Check')"
                    class="col-md-12"
                    :class="dynamicDisplayFieldClass"
                  >
                    <h5>Checks</h5>
                    <b-button
                      class="mb-2"
                      size="sm"
                      @click="
                        copyCheckContentToRule($root, relatedRule.checks_attributes[0].content)
                      "
                    >
                      Copy to {{ ruleStigId }}
                    </b-button>
                    <div
                      class="border p-2 overflow-auto"
                      style="background: #e9ecef; opacity: 1; height: 375px; line-height: 1.5"
                      v-html="
                        formatAndHighlightSearchWord(relatedRule.checks_attributes[0].content)
                      "
                    />
                  </b-card-text>
                  <b-card-text
                    v-if="fields.includes('Fix')"
                    class="col-md-12"
                    :class="dynamicDisplayFieldClass"
                  >
                    <h5>Fix</h5>
                    <b-button
                      class="mb-2"
                      size="sm"
                      @click="copyFixTextToRule($root, relatedRule.fixtext)"
                    >
                      Copy to {{ ruleStigId }}
                    </b-button>
                    <div
                      class="border p-2 overflow-auto"
                      style="background: #e9ecef; opacity: 1; height: 375px; line-height: 1.5"
                      v-html="formatAndHighlightSearchWord(relatedRule.fixtext)"
                    />
                  </b-card-text>
                </div>
              </b-card-body>
            </b-collapse>
          </b-card>
        </b-card-group>
      </div>
    </b-modal>
  </div>
</template>
<script>
import axios from "axios";
import VueSimpleSuggest from "vue-simple-suggest";
export default {
  name: "RelatedRulesModal",
  components: {
    VueSimpleSuggest,
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    ruleStigId: {
      type: String,
      required: true,
    },
  },
  data: function () {
    return {
      relatedRules: [],
      relatedRulesParents: [],
      filteredRules: [],
      selectedParent: "",
      keywordSearch: "",
      results: 0,
      stigsAndComponents: true,
      stigResultsOnly: true,
      componentResultsOnly: true,
      allFieldsSelected: true,
      indeterminate: false,
      controlFields: ["Vulnerability Discussion", "Check", "Fix"],
      fields: [],
    };
  },
  computed: {
    filteredGroupedRules: function () {
      const parentsNames = this.filteredParents.map((parent) => parent.displayed);
      // Filter by STIG / Component
      let rules = this.relatedRules.filter((r) => parentsNames.includes(r.parent));
      // Filter rules that includes the searchWord in check, fix, or discussion
      rules = this.lookupSearchWordInRules(rules);
      // Filter rules in a gven stig or component
      if (this.selectedParent) {
        rules = rules.filter((r) => r.parent === this.selectedParent);
      }
      this.updateTotalResults(rules);
      this.updateFilteredRules(rules);
      // Group results by stig / component name
      return rules.reduce((grouped, rule) => {
        let key = rule.parent;
        if (!grouped[key]) {
          grouped[key] = [];
        }
        grouped[key].push(rule);
        return grouped;
      }, {});
    },
    filteredParents: function () {
      let parents = this.relatedRulesParents;
      if (!this.stigsAndComponents && this.stigResultsOnly) {
        parents = parents.filter((parent) => !!parent.stig_id);
      } else if (!this.stigsAndComponents && this.componentResultsOnly) {
        parents = parents.filter((parent) => !parent.stig_id);
      }
      return parents;
    },
    dynamicDisplayFieldClass: function () {
      switch (this.fields.length) {
        case 1:
          return "col-xl-12";
          break;
        case 2:
          return "col-xl-6";
          break;
        default:
          return "col-xl-4";
      }
    },
  },
  watch: {
    fields: function (newValue, oldValue) {
      // Handle changes in individual field checkboxes
      if (newValue.length === 0) {
        this.indeterminate = false;
        this.allFieldsSelected = false;
      } else if (newValue.length === this.controlFields.length) {
        this.indeterminate = false;
        this.allFieldsSelected = true;
      } else {
        this.indeterminate = true;
        this.allFieldsSelected = false;
      }
    },
    keywordSearch: function (newValue) {
      if (newValue) {
        this.toggleAllCollapses(true);
      }
    },
  },
  methods: {
    resetModal: async function () {
      axios.get(`/rules/${this.rule.id}/search/related_rules`).then((response) => {
        this.fields = this.controlFields;
        this.relatedRules = response.data.rules;
        this.relatedRulesParents = response.data.parents;
        this.relatedRulesParents.forEach((parent) => {
          if (parent.stig_id) {
            parent.displayed = `${parent.stig_id.split("_").join(" ")}::${parent.version}`;
            const stig_rules = this.relatedRules.filter((r) => r.stig_id == parent.id);
            stig_rules.forEach((r) => {
              r.parent = parent.displayed;
              r.name = `${r.version}//${r.srg_id}`;
            });
          } else {
            const comp_rules = this.relatedRules.filter((r) => r.component_id == parent.id);
            parent.displayed = `${parent.name}::V${parent.version}R${parent.release}`;
            comp_rules.forEach((r) => {
              r.parent = parent.displayed;
              r.name = `${parent.prefix}-${r.rule_id}//${r.version}`;
            });
          }
        });
      });
    },
    resetFilters: function () {
      this.stigsAndComponents = true;
      this.stigResultsOnly = true;
      this.componentResultsOnly = true;
      this.allFieldsSelected = true;
      this.indeterminate = false;
      this.fields = this.controlFields;
      this.selectedParent = "";
      this.keywordSearch = "";
      this.toggleAllCollapses(false);
    },
    updateTotalResults: function (rules) {
      this.results = rules.length;
    },
    updateFilteredRules: function (rules) {
      this.filteredRules = rules;
    },
    lookupSearchWordInRules: function (rules) {
      const searchWord = this.keywordSearch.toLowerCase();
      return rules.filter((r) => {
        const discussion = r.disa_rule_descriptions_attributes[0].vuln_discussion.toLowerCase();
        const check = r.checks_attributes[0].content.toLowerCase();
        const fix = r.fixtext.toLowerCase();
        const includeCheck = this.fields.includes("Check");
        const includeFix = this.fields.includes("Fix");
        const includeDiscussion = this.fields.includes("Vulnerability Discussion");
        if (this.allFieldsSelected) {
          return (
            discussion.includes(searchWord) ||
            check.includes(searchWord) ||
            fix.includes(searchWord)
          );
        } else if (includeDiscussion && includeCheck) {
          return discussion.includes(searchWord) || check.includes(searchWord);
        } else if (includeDiscussion && includeFix) {
          return discussion.includes(searchWord) || fix.includes(searchWord);
        } else if (includeCheck && includeFix) {
          return check.includes(searchWord) || fix.includes(searchWord);
        } else if (includeDiscussion) {
          return discussion.includes(searchWord);
        } else if (includeCheck) {
          return check.includes(searchWord);
        } else {
          return fix.includes(searchWord);
        }
      });
    },
    formatAndHighlightSearchWord: function (text) {
      let formattedText = this.escapeHtml(text);
      if (this.keywordSearch) {
        let re = new RegExp(this.keywordSearch, "gi");
        formattedText = formattedText.replace(re, (match) => {
          return `<mark class='bg-warning'>${match}</mark>`;
        });
      }
      return formattedText.replace(/\n/g, "<br />");
    },
    escapeHtml: function (text) {
      return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
    },
    copyCheckContentToRule: function (root, checkContent) {
      const check = this.rule.checks_attributes[0];
      const content = `${check.content}\n\n ${checkContent}`;
      root.$emit("update:check", this.rule, { ...check, content }, 0);
      this.$bvToast.toast(`Check successfully copied to ${this.ruleStigId}`, {
        title: "Success",
        variant: "success",
        solid: true,
      });
    },
    copyDiscussionToRule: function (root, vulnDiscussion) {
      const discussion = this.rule.disa_rule_descriptions_attributes[0];
      const vuln_discussion = `${discussion.vuln_discussion}\n\n ${vulnDiscussion}`;
      root.$emit("update:disaDescription", this.rule, { ...discussion, vuln_discussion }, 0);
      this.$bvToast.toast(`Discussion successfully copied to ${this.ruleStigId}`, {
        title: "Success",
        variant: "success",
        solid: true,
      });
    },
    copyFixTextToRule: function (root, fix) {
      const fixtext = `${this.rule.fixtext} \n\n ${fix}`;
      root.$emit("update:rule", { ...this.rule, fixtext });
      this.$bvToast.toast(`Fix successfully copied to ${this.ruleStigId}`, {
        title: "Success",
        variant: "success",
        solid: true,
      });
    },
    toggleAllFields: function (checked) {
      this.fields = checked ? this.controlFields.slice() : [];
    },
    toggleAllCollapses: function (toggle) {
      this.filteredRules.forEach((rule) => {
        rule.show = toggle;
      });
    },
    setStigAndComponentFilter: function (switchText) {
      if (switchText === "all") {
        this.componentResultsOnly = true;
        this.stigResultsOnly = true;
      }
      this.stigsAndComponents = this.componentResultsOnly && this.stigResultsOnly ? true : false;
    },
  },
};
</script>
<style scoped></style>
