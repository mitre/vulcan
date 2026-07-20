import { ref, computed } from "vue";
import { getRelocations, markRelocation, unmarkRelocation } from "../api/rulesApi";

/**
 * Interim family identity: the technology token becomes a real component
 * field at release-identifier minting; until then the family is keyed by
 * the prefix's leading alpha segment (CNTR-00 -> CNTR) — decided
 * 2026-07-20. The backlog panel's explicit token filter means a
 * mismatched derivation hides nothing.
 */
export function familyTokenFromPrefix(prefix) {
  const match = (prefix || "").match(/^[A-Za-z]+/);
  return match ? match[0].toUpperCase() : null;
}

/**
 * useRelocations - relocation marker state for the component editor.
 *
 * ONE fetch of the caller-visible pending markers feeds all three
 * surfaces: the per-rule badge map (this component's rows only), the
 * per-family backlog (across components), and the open-time prompt
 * count keyed by the interim prefix-derived family token.
 *
 * Usage:
 *   const relocations = useRelocations({ id, prefix });
 *   await relocations.fetchMarkers();
 *
 * mark/unmark refresh the marker set on success and propagate failures
 * to the caller (which owns toasting via alertOrNotifyResponse).
 */
export function useRelocations(component) {
  const markers = ref([]);
  const loading = ref(false);

  const fetchMarkers = async () => {
    loading.value = true;
    try {
      const response = await getRelocations();
      markers.value = response.data || [];
    } finally {
      loading.value = false;
    }
  };

  const markersByRuleId = computed(() => {
    const map = {};
    markers.value
      .filter((marker) => marker.component_id === component.id)
      .forEach((marker) => {
        map[marker.source_rule_id] = marker;
      });
    return map;
  });

  const backlogFor = (token) =>
    markers.value.filter((marker) => marker.target_technology_token === token);

  const familyToken = computed(() => familyTokenFromPrefix(component.prefix));

  const familyBacklogCount = computed(() =>
    familyToken.value ? backlogFor(familyToken.value).length : 0,
  );

  const mark = async (ruleId, targetTechnologyToken) => {
    const response = await markRelocation(ruleId, targetTechnologyToken);
    await fetchMarkers();
    return response;
  };

  const unmark = async (relocationId) => {
    const response = await unmarkRelocation(relocationId);
    await fetchMarkers();
    return response;
  };

  return {
    markers,
    loading,
    fetchMarkers,
    markersByRuleId,
    backlogFor,
    familyToken,
    familyBacklogCount,
    mark,
    unmark,
  };
}
