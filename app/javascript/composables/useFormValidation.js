/**
 * useFormValidation — lightweight form validation composable for Vue 2.7
 *
 * DRY validation that mirrors backend model validations. No external dependencies.
 * Works with BootstrapVue's :state prop (true/false/null) and <b-form-invalid-feedback>.
 *
 * Usage:
 *   const { validate, fieldState, fieldError, isValid, touch, reset } = useFormValidation({
 *     name: { value: () => form.name, rules: { required: true } },
 *     prefix: { value: () => form.prefix, rules: { required: true, prefix: true } },
 *   });
 *
 *   // In template:
 *   <b-form-group :state="fieldState('name')" invalid-feedback="fieldError('name')">
 *     <b-form-input v-model="form.name" :state="fieldState('name')" @blur="touch('name')" />
 *   </b-form-group>
 */
import { ref, computed } from "vue";

// ─── Validation rules ───────────────────────────────────────
// Each rule returns an error message string or null if valid.
const RULES = {
  required: (value) => {
    if (value === null || value === undefined) return "This field is required";
    if (typeof value === "string" && !value.trim()) return "This field is required";
    return null;
  },

  prefix: (value) => {
    if (!value) return null; // let required handle empty
    return /^\w{4}-\w{2}$/.test(value) ? null : "Prefix must be of the form AAAA-00";
  },

  email: (value) => {
    if (!value) return null;
    return /^[^\s@]{1,64}@[^\s@]{1,255}$/.test(value) && value.includes(".")
      ? null
      : "Please enter a valid email address";
  },

  minLength: (min) => (value) => {
    if (!value) return null;
    return value.length >= min ? null : `Must be at least ${min} characters`;
  },

  pattern: (regex, message) => (value) => {
    if (!value) return null;
    return regex.test(value) ? null : message;
  },
};

/**
 * Create a form validation instance.
 *
 * @param {Object} fieldDefs - Field definitions keyed by field name.
 *   Each value: { value: () => currentValue, rules: { required: true, prefix: true, ... } }
 * @returns {Object} Validation API
 */
export function useFormValidation(fieldDefs) {
  // Track which fields the user has interacted with
  const touched = ref({});

  // Validate a single field, returns first error message or null
  function validateField(fieldName) {
    const def = fieldDefs[fieldName];
    if (!def) return null;

    const value = typeof def.value === "function" ? def.value() : def.value;
    const rules = def.rules || {};

    for (const [ruleName, ruleConfig] of Object.entries(rules)) {
      if (!ruleConfig) continue; // rule disabled (e.g., required: false)

      let validator;
      if (typeof ruleConfig === "function") {
        // Custom inline validator: { custom: (v) => error|null }
        validator = ruleConfig;
      } else if (typeof RULES[ruleName] === "function") {
        // Parameterized rules return a validator function
        const rule = RULES[ruleName];
        if (typeof ruleConfig === "boolean") {
          validator = rule;
        } else {
          // e.g., minLength: 5 → RULES.minLength(5) returns a function
          validator = rule(ruleConfig);
        }
      } else {
        continue;
      }

      // If validator itself returned a function (parameterized), call with value
      const error = typeof validator === "function" ? validator(value) : null;
      if (error) return error;
    }

    return null;
  }

  // Mark a field as touched (typically on blur)
  function touch(fieldName) {
    touched.value = { ...touched.value, [fieldName]: true };
  }

  // Mark all fields as touched (typically on submit attempt)
  function touchAll() {
    const allTouched = {};
    for (const key of Object.keys(fieldDefs)) {
      allTouched[key] = true;
    }
    touched.value = allTouched;
  }

  // Reset all touched state
  function reset() {
    touched.value = {};
  }

  // Get BootstrapVue :state for a field
  // Returns: null (untouched), true (valid), false (invalid)
  function fieldState(fieldName) {
    if (!touched.value[fieldName]) return null;
    return validateField(fieldName) === null;
  }

  // Get error message for a field (only when touched)
  function fieldError(fieldName) {
    if (!touched.value[fieldName]) return "";
    return validateField(fieldName) || "";
  }

  // Validate all fields, returns true if all pass
  function validate() {
    touchAll();
    for (const fieldName of Object.keys(fieldDefs)) {
      if (validateField(fieldName) !== null) return false;
    }
    return true;
  }

  // Computed: are all fields currently valid?
  const isValid = computed(() => {
    for (const fieldName of Object.keys(fieldDefs)) {
      if (validateField(fieldName) !== null) return false;
    }
    return true;
  });

  // Get all current errors (for debugging or summary display)
  function errors() {
    const result = {};
    for (const fieldName of Object.keys(fieldDefs)) {
      const error = validateField(fieldName);
      if (error) result[fieldName] = error;
    }
    return result;
  }

  return {
    validate,
    fieldState,
    fieldError,
    isValid,
    touch,
    touchAll,
    reset,
    errors,
  };
}

// Export rules for direct use in custom validators
export { RULES };
