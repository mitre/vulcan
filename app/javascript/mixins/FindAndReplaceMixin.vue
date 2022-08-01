<script>
import _ from "lodash";

const FIND_AND_REPLACE_FIELDS = {
  Title: ["title"],
  "Vulnerability Discussion": ["disa_rule_descriptions_attributes", 0, "vuln_discussion"],
  Check: ["checks_attributes", 0, "content"],
  Fix: ["fixtext"],
  "Vendor Comments": ["vendor_comments"],
};

// This mixin is for find and replace helper methods
export default {
  methods: {
    groupFindResults: function (data, find_text) {
      const find_results = {};
      data.forEach((rule) => {
        Object.entries(FIND_AND_REPLACE_FIELDS).forEach(([key, path]) => {
          const value = _.get(rule, path);
          if (value && value.toLowerCase().includes(find_text.toLowerCase())) {
            const result = {
              field: key,
              value: value,
              segments: this.getSegments(value, find_text),
            };
            if (rule.id in find_results) {
              find_results[rule.id].results.push(result);
            } else {
              find_results[rule.id] = {
                rule_id: rule.rule_id,
                results: [result],
              };
            }
          }
        });
      });
      return find_results;
    },
    getSegments: function (value, find_text) {
      const segments = [];
      const normalizedValue = value.toLowerCase();
      const normalizedFind = find_text.toLowerCase();
      const matchIndices = [];
      let currentIndex;
      let previousIndex = 0;
      while (true) {
        currentIndex = normalizedValue.indexOf(normalizedFind, previousIndex);
        if (currentIndex < 0) {
          break;
        }
        matchIndices.push(currentIndex);
        previousIndex = currentIndex + 1;
      }
      currentIndex = 0;
      matchIndices.forEach((index) => {
        segments.push({ text: value.substring(currentIndex, index), highlighted: false });
        currentIndex = index + find_text.length;
        segments.push({ text: value.substring(index, currentIndex), highlighted: true });
      });
      segments.push({ text: value.substring(currentIndex), highlighted: false });
      return segments;
    },
    replaceTextInRule: function (rule, field, segments, replace_text) {
      let modified_text = "";
      segments.forEach((segment) => {
        modified_text += segment.highlighted ? replace_text : segment.text;
      });
      _.set(rule, FIND_AND_REPLACE_FIELDS[field], modified_text);
    },
  },
};
</script>
