<template>
  <div>
    <div class="input-group">
      <input
        :id="id"
        v-model="localValue"
        :type="visible ? 'text' : 'password'"
        :name="name"
        :autocomplete="autocomplete"
        :required="required || undefined"
        :title="title"
        :autofocus="autofocus || undefined"
        :class="inputClasses"
        @input="onInput"
      />
      <div class="input-group-append">
        <button
          type="button"
          class="btn btn-outline-secondary"
          :aria-label="visible ? 'Hide password' : 'Show password'"
          @click="visible = !visible"
        >
          <b-icon :icon="visible ? 'eye-slash' : 'eye'" />
        </button>
      </div>
    </div>
    <ul
      v-if="policy && localValue.length > 0"
      data-testid="password-checklist"
      class="list-unstyled mt-2 mb-0 small"
    >
      <li
        v-for="(rule, index) in rules"
        :key="index"
        data-testid="password-rule"
        :class="rule.met ? 'text-success' : 'text-danger'"
      >
        <b-icon :icon="rule.met ? 'check-circle' : 'x-circle'" class="mr-1" />
        {{ rule.label }}
      </li>
    </ul>
    <div
      v-if="mustMatch !== undefined && localValue.length > 0"
      data-testid="password-match"
      class="mt-1 small"
      :class="passwordsMatch ? 'text-success' : 'text-danger'"
    >
      <b-icon :icon="passwordsMatch ? 'check-circle' : 'x-circle'" class="mr-1" />
      {{ passwordsMatch ? "Passwords match" : "Passwords do not match" }}
    </div>
  </div>
</template>

<script>
export default {
  name: "PasswordField",
  props: {
    name: { type: String, required: true },
    id: { type: String, default: undefined },
    value: { type: String, default: "" },
    autocomplete: { type: String, default: undefined },
    required: { type: Boolean, default: false },
    title: { type: String, default: undefined },
    autofocus: { type: Boolean, default: false },
    inputClass: { type: String, default: undefined },
    policy: { type: Object, default: null },
    mustMatch: { type: String, default: undefined },
  },
  data() {
    return {
      visible: false,
      localValue: this.value || "",
    };
  },
  computed: {
    inputClasses() {
      const classes = ["form-control"];
      if (this.inputClass) {
        classes.push(this.inputClass);
      }
      return classes;
    },
    rules() {
      if (!this.policy) return [];
      const r = [];
      const p = this.policy;
      const v = this.localValue;

      r.push({
        label: `At least ${p.min_length} characters`,
        met: v.length >= p.min_length,
      });

      const countMatches = (str, re) => (str.match(re) || []).length;

      if (p.min_uppercase > 0) {
        const n = p.min_uppercase;
        r.push({
          label: `At least ${n} uppercase letter${n > 1 ? "s" : ""}`,
          met: countMatches(v, /[A-Z]/g) >= n,
        });
      }
      if (p.min_lowercase > 0) {
        const n = p.min_lowercase;
        r.push({
          label: `At least ${n} lowercase letter${n > 1 ? "s" : ""}`,
          met: countMatches(v, /[a-z]/g) >= n,
        });
      }
      if (p.min_number > 0) {
        const n = p.min_number;
        r.push({
          label: `At least ${n} number${n > 1 ? "s" : ""}`,
          met: countMatches(v, /\d/g) >= n,
        });
      }
      if (p.min_special > 0) {
        const n = p.min_special;
        r.push({
          label: `At least ${n} special character${n > 1 ? "s" : ""}`,
          met: countMatches(v, /[^A-Za-z0-9]/g) >= n,
        });
      }
      return r;
    },
    allRulesMet() {
      return this.rules.length > 0 && this.rules.every((r) => r.met);
    },
    passwordsMatch() {
      if (this.mustMatch === undefined) return true;
      return this.localValue === this.mustMatch;
    },
  },
  watch: {
    value(newVal) {
      this.localValue = newVal;
    },
    allRulesMet: {
      handler(val) {
        if (this.policy) {
          this.$emit("update:valid", val);
        }
      },
      immediate: true,
    },
  },
  methods: {
    onInput() {
      this.$emit("input", this.localValue);
    },
  },
};
</script>
