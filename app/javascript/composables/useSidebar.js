import { ref } from "vue";

/**
 * Valid panel names for the sidebar
 */
export const panelNames = ["related", "satisfies", "reviews", "history"];

/**
 * Composable for managing sidebar panel state.
 * Controls which panel (if any) is currently open.
 *
 * @returns {Object} Sidebar state and methods
 */
function lockBodyScroll(val) {
  document.body.style.overflow = val ? "hidden" : "";
}

export function useSidebar() {
  // State
  const activePanel = ref(null);

  // Methods
  function togglePanel(panelName) {
    if (activePanel.value === panelName) {
      activePanel.value = null;
    } else {
      activePanel.value = panelName;
    }
    lockBodyScroll(activePanel.value);
  }

  function openPanel(panelName) {
    activePanel.value = panelName;
    lockBodyScroll(activePanel.value);
  }

  function closePanel() {
    activePanel.value = null;
    lockBodyScroll(null);
  }

  function isSidebarOpen(panelName) {
    return activePanel.value === panelName;
  }

  function isPanelActive(panelName) {
    return activePanel.value === panelName;
  }

  return {
    // State
    activePanel,

    // Constants
    panelNames,

    // Methods
    togglePanel,
    openPanel,
    closePanel,
    isSidebarOpen,
    isPanelActive,
  };
}
