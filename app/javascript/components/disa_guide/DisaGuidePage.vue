<template>
  <div class="disa-guide-page">
    <div class="disa-guide-layout">
      <aside class="disa-guide-sidebar">
        <div class="disa-guide-sidebar__header">
          <h5 class="mb-0">DISA Process Guide</h5>
        </div>
        <nav class="disa-guide-nav" aria-label="DISA Process Guide">
          <div v-for="section in pageSections" :key="section.label" class="disa-guide-nav__section">
            <small class="disa-guide-nav__label">{{ section.label }}</small>
            <a
              v-for="(title, slug) in section.pages"
              :key="slug"
              :href="'/disa-guide/' + slug"
              :class="['disa-guide-nav__link', { active: slug === currentPage }]"
            >
              {{ title }}
            </a>
          </div>
        </nav>
      </aside>

      <main class="disa-guide-main">
        <div class="disa-guide-main__header">
          <h5 class="mb-0">{{ pageTitle }}</h5>
          <b-button variant="link" class="ml-auto p-0 text-body" aria-label="Toggle dark mode" @click="toggleColorMode">
            <b-icon :icon="isDarkMode ? 'sun' : 'moon'" />
          </b-button>
        </div>
        <div class="disa-guide-content" v-html="htmlContent" />
      </main>

      <aside v-if="toc.length > 0" class="disa-guide-toc-panel">
        <div class="disa-guide-toc-panel__header">
          <small class="font-weight-bold">On this page</small>
        </div>
        <nav class="disa-guide-toc" aria-label="On this page">
          <a
            v-for="entry in toc"
            :key="entry.id"
            :href="'#' + entry.id"
            :class="['disa-guide-toc__link', 'toc-level-' + entry.level]"
            data-turbolinks="false"
          >
            {{ entry.text }}
          </a>
        </nav>
      </aside>
    </div>
  </div>
</template>

<script>
import { toggleTheme } from "../../utils/colorMode";

export default {
  name: "DisaGuidePage",
  props: {
    htmlContent: { type: String, required: true },
    pageTitle: { type: String, required: true },
    currentPage: { type: String, required: true },
    pageSections: { type: Array, required: true },
    toc: { type: Array, default: () => [] },
  },
  data() {
    return {
      isDarkMode: document.documentElement.getAttribute("data-bs-theme") === "dark",
    };
  },
  mounted() {
    this._observer = new MutationObserver(() => {
      this.isDarkMode = document.documentElement.getAttribute("data-bs-theme") === "dark";
    });
    this._observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-bs-theme"],
    });
  },
  beforeDestroy() {
    if (this._observer) this._observer.disconnect();
  },
  methods: {
    toggleColorMode() {
      toggleTheme();
    },
  },
};
</script>
