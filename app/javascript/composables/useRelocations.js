import { ref, computed } from "vue";
import {
  getRelocations,
  getRelocationDestinations,
  markRelocation,
  unmarkRelocation,
  dryRunRelocation,
  acceptRelocation,
  declineRelocation,
} from "../api/rulesApi";

/**
 * Interim SRG identity: the technology token becomes a real component
 * field at release-identifier minting; until then the SRG's token is
 * derived from the prefix's leading alpha segment (CNTR-00 -> CNTR) —
 * decided 2026-07-20. The backlog panel's explicit token filter means a
 * mismatched derivation hides nothing.
 */
export function technologyTokenFromPrefix(prefix) {
  const match = (prefix || "").match(/^[A-Za-z]+/);
  return match ? match[0].toUpperCase() : null;
}

/**
 * useRelocations - relocation proposal state for the component editor.
 *
 * ONE fetch of the caller-visible rows feeds all three surfaces: the
 * per-rule badge map (this component's rows only), the per-SRG
 * backlog (across components), and the open-time prompt count keyed by
 * the interim prefix-derived technology token. The server retains DECLINED
 * proposals in the response for source-author visibility — those are
 * not open markers, so every marker surface filters to open proposals.
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
  // Destination SRG options for the propose picker.
  const destinations = ref([]);

  const fetchMarkers = async () => {
    loading.value = true;
    try {
      const response = await getRelocations();
      markers.value = response.data || [];
    } finally {
      loading.value = false;
    }
  };

  const fetchDestinations = async () => {
    const response = await getRelocationDestinations();
    destinations.value = response.data || [];
  };

  const openProposal = (marker) => !marker.declined_at;

  const markersByRuleId = computed(() => {
    const map = {};
    markers.value
      .filter((marker) => openProposal(marker) && marker.component_id === component.id)
      .forEach((marker) => {
        map[marker.source_rule_id] = marker;
      });
    return map;
  });

  const backlogFor = (token) =>
    markers.value.filter(
      (marker) => openProposal(marker) && marker.target_technology_token === token,
    );

  const technologyToken = computed(() => technologyTokenFromPrefix(component.prefix));

  const srgBacklogCount = computed(() =>
    technologyToken.value ? backlogFor(technologyToken.value).length : 0,
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

  // Receiver-side adjudication against THIS component: the dry-run is a
  // zero-write preview (no refresh); accept and decline terminate the
  // proposal, so both refresh the marker set on success.
  const dryRun = (relocationId) => dryRunRelocation(relocationId, component.id);

  const accept = async (relocationId) => {
    const response = await acceptRelocation(relocationId, component.id);
    await fetchMarkers();
    return response;
  };

  const decline = async (relocationId, adjudicationRationale) => {
    const response = await declineRelocation(relocationId, component.id, adjudicationRationale);
    await fetchMarkers();
    return response;
  };

  return {
    markers,
    loading,
    destinations,
    fetchMarkers,
    fetchDestinations,
    markersByRuleId,
    backlogFor,
    technologyToken,
    srgBacklogCount,
    mark,
    unmark,
    dryRun,
    accept,
    decline,
  };
}
