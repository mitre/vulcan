# frozen_string_literal: true

# Seed one component_source_srgs row per component from the existing single
# parent (based_on). Runs outside a DDL transaction and in batches so a large
# table never locks for long, and is idempotent (the unique index makes
# insert_all skip conflicts) so a partial run resumes cleanly.
class BackfillComponentSourceSrgs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  # Migration-local models — insulated from app-model callbacks/validations and
  # from future schema drift.
  class Component < ActiveRecord::Base
    self.table_name = 'components'
  end

  class ComponentSourceSrg < ActiveRecord::Base
    self.table_name = 'component_source_srgs'
  end

  def up
    now = Time.current
    Component.where.not(security_requirements_guide_id: nil).in_batches(of: 1000) do |batch|
      rows = batch.pluck(:id, :security_requirements_guide_id).map do |component_id, srg_id|
        { component_id: component_id, security_requirements_guide_id: srg_id,
          created_at: now, updated_at: now }
      end
      ComponentSourceSrg.insert_all(rows, unique_by: %i[component_id security_requirements_guide_id])
    end
  end

  def down
    ComponentSourceSrg.delete_all
  end
end
