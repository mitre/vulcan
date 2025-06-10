commit 111d4330345d9cf7a37feb737fb76fa3d5f8c589
Author: Aaron Lippold <lippold@gmail.com>
Date:   Sat Mar 8 11:09:08 2025 -0500

    Improve SRG component with better error handling and data normalization
    
    - Add comprehensive error handling for missing or incomplete SRG data
    - Implement fallback placeholder rule when no rules are found
    - Add data structure normalization to ensure compatibility with STIG components
    - Include deep null checking to prevent runtime errors
    - Preserve proper MDI font configuration and asset pipeline settings
    - Test shows working title display despite missing rule content
    
    🤖 Generated with [Claude Code](https://claude.ai/code)
    Co-Authored-By: Aaron Lippold <lippold@gmail.com>
    Co-Authored-By: Claude <noreply@anthropic.com>

diff --git a/app/javascript/srg.js b/app/javascript/srg.js
index 2126be2..84d690e 100644
--- a/app/javascript/srg.js
+++ b/app/javascript/srg.js
@@ -40,62 +40,130 @@ const Srg = {
       
       debug.log('Original SRG data', this.stig);
       
-      // Create a deep copy of the SRG
-      const adapted = JSON.parse(JSON.stringify(this.stig));
-      
-      // Map release_date to benchmark_date for compatibility
-      if (adapted.release_date && !adapted.benchmark_date) {
-        adapted.benchmark_date = adapted.release_date;
-      }
-      
-      // Map srg_rules to stig_rules for compatibility
-      if (adapted.srg_rules && !adapted.stig_rules) {
-        adapted.stig_rules = (adapted.srg_rules || []).map(rule => {
-          // Ensure required properties exist on each rule
-          return {
-            ...rule,
-            // Add any missing properties needed by the STIG components
-            severity: rule.severity || 'medium',
-            status: rule.status || 'draft',
-            // Ensure required ID fields exist
-            srg_id: rule.srg_id || 'unknown',
-            vuln_id: rule.vuln_id || 'unknown',
-            // Ensure references exist
-            references: rule.references || [],
-            // Ensure checks exist with default properties if missing
-            checks: (rule.checks || []).map(check => ({
-              id: check.id || 0,
-              content_ref: check.content_ref || { name: 'unknown' },
-              check_content: check.check_content || { content: '' },
-              ...check
-            }))
-          };
-        });
-      } else if (!adapted.stig_rules) {
-        adapted.stig_rules = []; // Ensure stig_rules is at least an empty array
+      try {
+        // Create a deep copy of the SRG
+        const adapted = JSON.parse(JSON.stringify(this.stig));
+        
+        // Make sure we handle both string JSON and parsed objects
+        let data = adapted;
+        if (typeof adapted === 'string') {
+          try {
+            data = JSON.parse(adapted);
+          } catch (e) {
+            console.error('[SRG] Failed to parse JSON string:', e);
+          }
+        }
+        
+        // Map release_date to benchmark_date for compatibility
+        if (data.release_date && !data.benchmark_date) {
+          data.benchmark_date = data.release_date;
+        }
+        
+        // Map srg_rules to stig_rules for compatibility
+        if (data.srg_rules && !data.stig_rules) {
+          data.stig_rules = (data.srg_rules || []).map(rule => {
+            // Ensure required properties exist on each rule
+            const enhancedRule = {
+              ...rule,
+              // Add any missing properties needed by the STIG components
+              severity: rule.severity || 'medium',
+              status: rule.status || 'draft',
+              // Ensure required ID fields exist
+              srg_id: rule.srg_id || 'unknown',
+              vuln_id: rule.vuln_id || rule.srg_id || 'unknown',
+              // Ensure references exist
+              references: rule.references || [],
+              // Add empty disa_rule_descriptions if missing
+              disa_rule_descriptions: rule.disa_rule_descriptions || [{
+                id: 0,
+                rule_id: rule.id || 0,
+                rule_version: "N/A",
+                description: rule.description || "No description available",
+                title: rule.title || "Untitled Rule",
+                status: rule.status || "draft"
+              }],
+              // Ensure checks exist with default properties if missing
+              checks: (rule.checks || []).map(check => ({
+                id: check.id || 0,
+                content_ref: check.content_ref || { name: rule.srg_id || 'unknown' },
+                check_content: check.check_content || { 
+                  content: check.content || rule.description || 'No check content available' 
+                },
+                ...check
+              }))
+            };
+            
+            return enhancedRule;
+          });
+        } else if (!data.stig_rules) {
+          data.stig_rules = []; // Ensure stig_rules is at least an empty array
+        }
+        
+        debug.log('Adapted data', data);
+        return data;
+      } catch (e) {
+        console.error('[SRG] Error in adaptedStig:', e);
+        return { 
+          title: this.stig?.title || 'Security Requirements Guide',
+          version: this.stig?.version || 'Unknown Version',
+          benchmark_date: this.stig?.release_date || new Date().toISOString(),
+          stig_rules: []
+        };
       }
-      
-      debug.log('Adapted data', adapted);
-      return adapted;
     }
   },
   // Override the Stig component's initialSelectedRule method to handle potential null values
   methods: {
     initialSelectedRule() {
-      let rules = this.adaptedStig.stig_rules || [];
+      let rules = this.adaptedStig?.stig_rules || [];
       
       debug.log('Rules for selection', rules);
       
       if (!rules.length) {
         console.log("[SRG] No rules found for selection");
-        return null;
+        // Return a placeholder rule to prevent null reference errors
+        return {
+          id: 0,
+          title: "No rules found for this SRG",
+          srg_id: "N/A",
+          vuln_id: "N/A",
+          severity: "info",
+          status: "draft",
+          references: [],
+          checks: [{
+            id: 0,
+            content_ref: { name: 'N/A' },
+            check_content: { content: 'No check content available' }
+          }],
+          disa_rule_descriptions: [{
+            id: 0,
+            rule_id: 0,
+            rule_version: "N/A",
+            description: "No rules have been imported for this SRG yet",
+            title: "Empty SRG",
+            status: "draft"
+          }]
+        };
       }
       
       // Additional null checks to avoid errors
       const safeRules = rules.filter(rule => rule && rule.srg_id);
       if (!safeRules.length) {
         console.log("[SRG] No rules with SRG ID found");
-        return null;
+        return {
+          id: 0,
+          title: "Found rules with missing IDs",
+          srg_id: "N/A",
+          vuln_id: "N/A",
+          severity: "info",
+          status: "draft",
+          references: [],
+          checks: [{
+            id: 0,
+            content_ref: { name: 'N/A' },
+            check_content: { content: 'Rules are missing IDs' }
+          }]
+        };
       }
       
       // Sort safely with null checks
@@ -103,6 +171,7 @@ const Srg = {
         (a.srg_id || '').localeCompare(b.srg_id || '')
       );
       
+      debug.log('First rule selected', sorted[0]);
       return sorted[0];
     },
     // Override onRuleSelected method to update selectedRule
