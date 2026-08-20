<template>
  <span class="color-swatch" :style="{ backgroundColor: color }" :title="color" />
</template>

<script>
export default {
  name: "ColorSwatch",
  props: {
    color: { type: String, required: true },
  },
};
</script>

<style scoped>
.color-swatch {
  display: inline-block;
  width: 14px;
  height: 14px;
  border-radius: 3px;
  border: 1px solid rgba(0, 0, 0, 0.15);
  vertical-align: middle;
  margin-right: 4px;
}
</style>
