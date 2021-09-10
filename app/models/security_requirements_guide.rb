# frozen_string_literal: true

class SecurityRequirementsGuide < ApplicationRecord
  validates :srg_id, :title, :version, :xml, presence: true
  validates :srg_id, uniqueness: {
     scope: :version,
     message: ' ID has already been taken'
  }

  # Since an SRG is top-level, the parameter is the entire parsed benchmark
  def self.from_mapping(benchmark_mapping)
    SecurityRequirementsGuide.new(
      srg_id: benchmark_mapping.id,
      title: benchmark_mapping.title.first,
      version: benchmark_mapping.version.version
    )
  end
end
