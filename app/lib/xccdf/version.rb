# frozen_string_literal: true

module Xccdf
  # Type for a version number, with a timestamp attribute
  # for when the version was made.
  class Version
    include HappyMapper

    tag 'version'

    attribute :time, String, tag: 'update'
    attribute :update, String, tag: 'update'

    content :version, String
  end
end
