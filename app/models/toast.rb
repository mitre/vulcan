# frozen_string_literal: true

# Canonical toast response object. Enforces the {title, message: Array, variant}
# contract at construction time so controllers cannot produce invalid shapes.
class Toast
  attr_reader :title, :message, :variant

  VALID_VARIANTS = %w[danger warning success info].freeze

  def initialize(title:, message:, variant: 'danger')
    @title = title
    @message = Array(message).freeze
    @variant = variant
  end

  def as_json(_options = nil)
    { 'title' => @title, 'message' => @message, 'variant' => @variant }
  end

  def to_json(*)
    as_json.to_json(*)
  end
end
