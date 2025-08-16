<template>
  <!-- eslint-disable-next-line vue/no-v-html -->
  <div ref="mermaidRef" class="mermaid" v-html="svg" />
</template>

<script setup>
import { ref, onMounted, watch } from "vue";
import mermaid from "mermaid";

const props = defineProps({
  graph: {
    type: String,
    required: true,
  },
});

const mermaidRef = ref(null);
const svg = ref("");

const renderMermaid = async () => {
  mermaid.initialize({
    startOnLoad: false,
    theme: "default",
    themeVariables: {
      primaryColor: "#3eaf7c",
      primaryTextColor: "#fff",
      primaryBorderColor: "#2c8658",
      lineColor: "#5c5c5c",
      secondaryColor: "#4fc08d",
      tertiaryColor: "#fff",
    },
  });

  const { svg: renderedSvg } = await mermaid.render("mermaid-" + Date.now(), props.graph);
  svg.value = renderedSvg;
};

onMounted(() => {
  renderMermaid();
});

watch(
  () => props.graph,
  () => {
    renderMermaid();
  },
);
</script>

<style scoped>
.mermaid {
  text-align: center;
  margin: 2rem 0;
}
</style>
