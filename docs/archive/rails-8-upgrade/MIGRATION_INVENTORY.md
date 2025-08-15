# Asset Pack Tags Migration Inventory

**STATUS: COMPLETED** - All Webpacker assets have been successfully migrated to jsbundling-rails with esbuild.

This file documented the migration from Webpacker to jsbundling-rails that was completed as part of the Rails 8.0.2.1 upgrade.

## Migration Summary

All Webpacker pack tags have been successfully replaced:
- `javascript_pack_tag` → `javascript_include_tag`
- `stylesheet_pack_tag` → `stylesheet_link_tag`
- Webpacker removed from Gemfile
- Assets now compiled with esbuild via jsbundling-rails
- Using Propshaft for asset pipeline (no Sprockets)

## Entry Point Mapping

All entry points have been successfully migrated to esbuild configuration.
