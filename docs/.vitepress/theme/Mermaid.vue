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
    // Mermaid 12 changed the flowchart defaults (ELK layout, neo look,
    // 120px label wrapping and minimum width). Keep the dagre layout, classic
    // look and 200px wrapping the site's diagrams were drawn for.
    layout: "dagre",
    look: "classic",
    flowchart: { wrappingWidth: 200, minNodeWidth: 0 },
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

  // Render inside this component's element so labels are measured with the
  // same page styles they are displayed with.
  const { svg: renderedSvg } = await mermaid.render(
    "mermaid-" + Date.now(),
    props.graph,
    mermaidRef.value,
  );
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
