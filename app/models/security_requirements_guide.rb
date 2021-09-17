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
      version: "V#{benchmark_mapping.version.version}#{SecurityRequirementsGuide.revision(benchmark_mapping.plaintext.first)}"
    )
  end

  private

  # If the SRGs do not conform nicely and this function gets complex, remove the version parse logic
  # and do not display detailed version information. Make SRG producers actually provide consistent
  # metadata.
  def self.revision(plaintext_mapping)
    revision_string = plaintext_mapping.plaintext.split('Release: ')[1]
    return '' if revision_string.nil?

    return "R#{revision_string.match(/^\d+/)[0]}"
  end
end
