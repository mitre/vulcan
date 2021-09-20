# frozen_string_literal: true

module Xccdf
  # Data type for the fixText element that represents
  # a rich text string, with substitutions allowed, and
  # a series of attributes that qualify the fix.
  class FixText
    include HappyMapper

    tag 'fixtext'

    attribute :fixref, String, tag: 'fixref'
    attribute :reboot, Boolean, tag: 'reboot'
    # Allowed strategy keyword values for a Rule fix or
    # fixtext.  The allowed values are:
    #    unknown= strategy not defined (default for forward
    #           compatibility for XCCDF 1.0)
    #    configure=adjust target config or settings
    #    patch=apply a patch, hotfix, or update
    #    policy=remediation by changing policies/procedures
    #    disable=turn off or deinstall something
    #    enable=turn on or install something
    #    restrict=adjust permissions or ACLs
    #    update=install upgrade or update the system
    #    combination=combo of two or more of the above
    attribute :strategy, String, tag: 'strategy'
    # Allowed rating values values for a Rule fix
    # or fixtext: disruption, complexity, and maybe overhead.
    # The possible values are:
    #    unknown= rating unknown or impossible to estimate
    #        (default for forward compatibility for XCCDF 1.0)
    #    low = little or no potential for disruption,
    #            very modest complexity
    #    medium= some chance of minor disruption,
    #             substantial complexity
    #    high = likely to cause serious disruption, very complex
    attribute :disruption, String, tag: 'disruption'
    # Allowed rating values values for a Rule fix
    # or fixtext: disruption, complexity, and maybe overhead.
    # The possible values are:
    #    unknown= rating unknown or impossible to estimate
    #        (default for forward compatibility for XCCDF 1.0)
    #    low = little or no potential for disruption,
    #            very modest complexity
    #    medium= some chance of minor disruption,
    #             substantial complexity
    #    high = likely to cause serious disruption, very complex
    attribute :complexity, String, tag: 'complexity'

    # HTML Text
    content :fixtext, String
  end
end
