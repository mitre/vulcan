# frozen_string_literal: true

# Patch HappyMapper to use NONET parse option, preventing XML external entity
# attacks and SSRF via external DTD fetching.
#
# HappyMapper defaults to Nokogiri::XML::ParseOptions::STRICT (0), which allows
# network access during XML parsing. Adding NONET blocks all network fetches.
module HappyMapperNonetPatch
  def parse(xml, options = {})
    if xml.is_a?(String)
      # Pre-parse with NONET to block network access, then let HappyMapper process
      doc = Nokogiri::XML(xml) do |config|
        config.nonet
        config.strict
      end
      super(doc, options)
    else
      super
    end
  end
end

# Apply the patch to HappyMapper's class-level parse
HappyMapper::ClassMethods.prepend(HappyMapperNonetPatch)
