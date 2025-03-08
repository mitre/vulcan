// SRG entry point
import Vue from 'vue'
import TurbolinksAdapter from 'vue-turbolinks'
import { BootstrapVue, IconsPlugin } from 'bootstrap-vue'
import Stig from './components/stigs/Stig.vue'  // Reuse the Stig component
import linkify from 'vue-linkify'
import DateFormatMixin from './mixins/DateFormatMixin.vue'

// Use Vue plugins
Vue.use(TurbolinksAdapter)
Vue.use(BootstrapVue)
Vue.use(IconsPlugin)

// Register Vue directives
Vue.directive('linkified', linkify)

// Improved debug utilities
const debug = {
  log: (title, data) => {
    console.log(`[SRG Debug] ${title}:`, data);
    return data;
  }
};

// Create an adapted component that handles SRG data structure
const Srg = {
  extends: Stig,
  name: "Srg",
  mixins: [DateFormatMixin], // Add date formatting capabilities
  data() {
    return {
      // Initialize with default empty data to prevent null/undefined errors
      selectedRule: null,
    };
  },
  computed: {
    // Adapt SRG data structure to match what Stig component expects
    adaptedStig() {
      if (!this.stig) return { stig_rules: [] };
      
      debug.log('Original SRG data', this.stig);
      
      try {
        // Create a deep copy of the SRG
        const adapted = JSON.parse(JSON.stringify(this.stig));
        
        // Make sure we handle both string JSON and parsed objects
        let data = adapted;
        if (typeof adapted === 'string') {
          try {
            data = JSON.parse(adapted);
          } catch (e) {
            console.error('[SRG] Failed to parse JSON string:', e);
          }
        }
        
        // Map release_date to benchmark_date for compatibility
        if (data.release_date && !data.benchmark_date) {
          data.benchmark_date = data.release_date;
        }
        
        // Map srg_rules to stig_rules for compatibility
        if (data.srg_rules && !data.stig_rules) {
          data.stig_rules = (data.srg_rules || []).map(rule => {
            // Ensure required properties exist on each rule
            const enhancedRule = {
              ...rule,
              // Add any missing properties needed by the STIG components
              severity: rule.severity || 'medium',
              status: rule.status || 'draft',
              // Ensure required ID fields exist
              srg_id: rule.srg_id || 'unknown',
              vuln_id: rule.vuln_id || rule.srg_id || 'unknown',
              // Ensure references exist
              references: rule.references || [],
              // Add empty disa_rule_descriptions if missing
              disa_rule_descriptions: rule.disa_rule_descriptions || [{
                id: 0,
                rule_id: rule.id || 0,
                rule_version: "N/A",
                description: rule.description || "No description available",
                title: rule.title || "Untitled Rule",
                status: rule.status || "draft"
              }],
              // Ensure checks exist with default properties if missing
              checks: (rule.checks || []).map(check => ({
                id: check.id || 0,
                content_ref: check.content_ref || { name: rule.srg_id || 'unknown' },
                check_content: check.check_content || { 
                  content: check.content || rule.description || 'No check content available' 
                },
                ...check
              }))
            };
            
            return enhancedRule;
          });
        } else if (!data.stig_rules) {
          data.stig_rules = []; // Ensure stig_rules is at least an empty array
        }
        
        debug.log('Adapted data', data);
        return data;
      } catch (e) {
        console.error('[SRG] Error in adaptedStig:', e);
        return { 
          title: this.stig?.title || 'Security Requirements Guide',
          version: this.stig?.version || 'Unknown Version',
          benchmark_date: this.stig?.release_date || new Date().toISOString(),
          stig_rules: []
        };
      }
    }
  },
  // Override the Stig component's initialSelectedRule method to handle potential null values
  methods: {
    initialSelectedRule() {
      let rules = this.adaptedStig?.stig_rules || [];
      
      debug.log('Rules for selection', rules);
      
      if (!rules.length) {
        console.log("[SRG] No rules found for selection");
        // Return a placeholder rule to prevent null reference errors
        return {
          id: 0,
          title: "No rules found for this SRG",
          srg_id: "N/A",
          vuln_id: "N/A",
          severity: "info",
          status: "draft",
          references: [],
          checks: [{
            id: 0,
            content_ref: { name: 'N/A' },
            check_content: { content: 'No check content available' }
          }],
          disa_rule_descriptions: [{
            id: 0,
            rule_id: 0,
            rule_version: "N/A",
            description: "No rules have been imported for this SRG yet",
            title: "Empty SRG",
            status: "draft"
          }]
        };
      }
      
      // Additional null checks to avoid errors
      const safeRules = rules.filter(rule => rule && rule.srg_id);
      if (!safeRules.length) {
        console.log("[SRG] No rules with SRG ID found");
        return {
          id: 0,
          title: "Found rules with missing IDs",
          srg_id: "N/A",
          vuln_id: "N/A",
          severity: "info",
          status: "draft",
          references: [],
          checks: [{
            id: 0,
            content_ref: { name: 'N/A' },
            check_content: { content: 'Rules are missing IDs' }
          }]
        };
      }
      
      // Sort safely with null checks
      const sorted = safeRules.sort((a, b) => 
        (a.srg_id || '').localeCompare(b.srg_id || '')
      );
      
      debug.log('First rule selected', sorted[0]);
      return sorted[0];
    },
    // Override onRuleSelected method to update selectedRule
    onRuleSelected(rule) {
      debug.log('Rule selected', rule);
      this.selectedRule = rule;
    }
  },
  created() {
    console.log("[SRG Component] Created");
    debug.log("SRG Data received", this.stig);
    debug.log("Adapted data", this.adaptedStig);
  },
  mounted() {
    console.log("[SRG Component] Mounted");
  },
  // Override the props to use the adapted data
  render(h) {
    console.log("[SRG Component] Rendering with adapted data");
    // Pass the adapted data to the Stig component
    return h(Stig, {
      props: {
        stig: this.adaptedStig
      }
    });
  }
};

// Register the component globally
Vue.component('Srg', Srg)
Vue.component('srg', Srg)  // Register with lowercase for case insensitivity

// Enhanced initialization with better error handling
const initializeSrg = () => {
  console.log("[SRG] Initializing SRG component");
  const element = document.getElementById('srg')
  
  if (element) {
    console.log("[SRG] Found SRG container element");
    try {
      new Vue({
        el: '#srg',
        mounted() {
          console.log("[SRG] Vue instance mounted successfully");
        }
      })
      console.log("[SRG] Vue instance created successfully");
    } catch (error) {
      console.error("[SRG] Error initializing Vue instance:", error);
    }
  } else {
    console.log("[SRG] No SRG container element found in the current page");
  }
}

// Use both event listeners for maximum compatibility
document.addEventListener('turbolinks:load', () => {
  console.log("[SRG] Turbolinks load event fired");
  initializeSrg();
})

document.addEventListener('DOMContentLoaded', () => {
  console.log("[SRG] DOMContentLoaded event fired");
  initializeSrg();
})