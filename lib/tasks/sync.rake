# frozen_string_literal: true

# Component sync CLI — Phase 1 read-only diagnostics.
#
# Exit codes (per expert review F15):
#   0 — clean merge, no conflicts (Applier can run auto-resolutions)
#   1 — conflicts present, human reconciliation required
#   2 — runtime error (precondition violation, missing zip, etc.)
namespace :sync do
  desc 'Diff two backup archives (ours vs theirs). ENV: OURS, THEIRS [, MANIFEST_VERSION]'
  task diff: :environment do
    code = Import::JsonArchive::Merge::SyncRakeRunner.new($stdout, $stderr).diff(
      ours_path: ENV.fetch('OURS'),
      theirs_path: ENV.fetch('THEIRS')
    )
    exit(code)
  end

  desc 'Preview merge of an archive against a live component. ENV: COMPONENT_ID, THEIRS'
  task preview: :environment do
    code = Import::JsonArchive::Merge::SyncRakeRunner.new($stdout, $stderr).preview(
      component_id: ENV.fetch('COMPONENT_ID').to_i,
      theirs_path: ENV.fetch('THEIRS')
    )
    exit(code)
  end
end
