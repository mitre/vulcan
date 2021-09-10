# frozen_string_literal: true

module Xccdf
  class Warning
    include HappyMapper

    tag 'warning'

    # Allowed warning category keywords for the warning
    # element.  The allowed categories are:
    #    general=broad or general-purpose warning (default
    #           for compatibility for XCCDF 1.0)
    #    functionality=warning about possible impacts to
    #           functionality or operational features
    #    performance=warning about changes to target
    #           system performance or throughput
    #    hardware=warning about hardware restrictions or
    #           possible impacts to hardware
    #    legal=warning about legal implications
    #    regulatory=warning about regulatory obligations
    #           or compliance implications
    #    management=warning about impacts to the mgmt
    #           or administration of the target system
    #    audit=warning about impacts to audit or logging
    #    dependency=warning about dependencies between
    #           this Rule and other parts of the target
    #           system, or version dependencies.
    attribute :category, String, tag: 'category'

    content :warning, String
  end
end
