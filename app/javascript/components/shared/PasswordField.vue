<template>
  <div class="input-group">
    <input
      v-model="localValue"
      :type="visible ? 'text' : 'password'"
      :name="name"
      :id="id"
      :autocomplete="autocomplete"
      :required="required || undefined"
      :title="title"
      :autofocus="autofocus || undefined"
      :class="inputClasses"
      @input="$emit('input', localValue)"
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
  },
  data() {
    return {
      visible: false,
      localValue: this.value || "",
    };
  },
  watch: {
    value(newVal) {
      this.localValue = newVal;
    },
  },
  computed: {
    inputClasses() {
      const classes = ["form-control"];
      if (this.inputClass) {
        classes.push(this.inputClass);
      }
      return classes;
    },
  },
};
</script>
