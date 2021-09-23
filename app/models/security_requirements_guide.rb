# frozen_string_literal: true

# SecurityRequirementsGuides (abbreviated SRGs) are XCCDF documents that contain a
# benchmark that describes how to evaluate generic IT systems.
class SecurityRequirementsGuide < ApplicationRecord
  validates :srg_id, :title, :version, :xml, presence: true
  validates :srg_id, uniqueness: {
    scope: :version,
    message: ' ID has already been taken'
  }

  # Since an SRG is top-level, the parameter is the entire parsed benchmark
  def self.from_mapping(benchmark_mapping)
    # Disabling `Style/RescueModifier` here because the goal is simply just to try and
    # fetch the attribute, but return `nil` if anything goes wrong with parsing.
    # rubocop:disable Style/RescueModifier
    id = benchmark_mapping.id rescue nil
    title = benchmark_mapping.title.first rescue nil
    version = "V#{benchmark_mapping.version.version}" \
              "#{SecurityRequirementsGuide.revision(benchmark_mapping.plaintext.first)}" rescue nil
    # rubocop:enable Style/RescueModifier

    SecurityRequirementsGuide.new(srg_id: id, title: title, version: version)
  end

  # If the SRGs do not conform nicely and this function gets complex, remove the version parse logic
  # and do not display detailed version information. Make SRG producers actually provide consistent
  # metadata.
  def self.revision(plaintext_mapping)
    revision_string = plaintext_mapping.plaintext.split('Release: ')[1]
    return '' if revision_string.nil?

    "R#{revision_string.match(/^\d+/)[0]}"
  end
end
