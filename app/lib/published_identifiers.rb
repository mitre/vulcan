# frozen_string_literal: true

# Working-convention published identifiers for authored SRG requirements
# (DISA assigns real V-/SV- numbers at publication; drafts publish under
# these). ONE home for the compositions: the XCCDF emission and the
# release catalog copy must agree byte-for-byte — the basing import joins
# the artifact's Rule element ids against catalog rule_id columns.
module PublishedIdentifiers
  module_function

  def group(prefix, rule_id)
    "V-#{prefix}-#{rule_id}"
  end

  def rule(prefix, rule_id)
    "SV-#{prefix}-#{rule_id}"
  end

  def fixref(prefix, rule_id)
    "F-#{prefix}-#{rule_id}_fix"
  end

  def check(prefix, rule_id)
    "C-#{prefix}-#{rule_id}_chk"
  end
end
