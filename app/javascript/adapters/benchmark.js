/**
 * Benchmark Adapters
 *
 * Normalize STIG and SRG data into a unified structure for BenchmarkViewer.
 * This allows shared components to work with both types without knowing
 * the structural differences.
 *
 * Pattern from v2.3.0: Adapter functions at the component boundary transform
 * DB-specific structures into a common interface.
 */

/**
 * Normalize STIG data to unified benchmark structure
 *
 * @param {Object} stig - STIG object from Rails API
 * @returns {Object} Normalized benchmark object
 */
export function stigToBenchmark(stig) {
  return {
    id: stig.id,
    benchmark_id: stig.stig_id,
    title: stig.title,
    version: stig.version,
    date: stig.benchmark_date,
    rules: stig.stig_rules || [],
  };
}

/**
 * Normalize SRG data to unified benchmark structure
 *
 * @param {Object} srg - SRG object from Rails API
 * @returns {Object} Normalized benchmark object
 */
export function srgToBenchmark(srg) {
  return {
    id: srg.id,
    benchmark_id: srg.srg_id,
    title: srg.title,
    version: srg.version,
    date: srg.release_date,
    rules: srg.srg_rules || [],
  };
}

/**
 * Normalize Component data to unified benchmark structure
 *
 * Components are "STIGs in progress" — released components are read-only
 * and can be viewed using the same BenchmarkViewer as STIGs/SRGs.
 *
 * @param {Object} component - Component object from Rails API (with rules method)
 * @returns {Object} Normalized benchmark object
 */
export function componentToBenchmark(component) {
  return {
    id: component.id,
    benchmark_id: component.prefix || component.name,
    title: `${component.name} (${component.based_on_title} ${component.based_on_version})`,
    version: `V${component.version}R${component.release}`,
    date: component.updated_at,
    rules: component.rules || [],
  };
}
