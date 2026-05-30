# frozen_string_literal: true

# Personal access token for programmatic API access (GitLab/Discourse pattern).
class PersonalAccessToken < ApplicationRecord
  belongs_to :user

  audited associated_with: :user, except: %i[token_digest token_prefix]

  VALID_SCOPES = %w[read write admin].freeze
  MAX_TOKENS_PER_USER = 20
  MAX_LIFETIME_DAYS = 365
  TOKEN_PREFIX = 'vulcan_'

  serialize :scopes, coder: JSON
  serialize :allowed_ips, coder: JSON

  attr_reader :raw_token

  scope :active, -> { where(revoked_at: nil).where('expires_at IS NULL OR expires_at > ?', Date.current) }
  scope :not_revoked, -> { where(revoked_at: nil) }

  validates :name, presence: true
  validates :scopes, presence: true
  validate :scopes_are_valid
  validate :expires_at_within_max_lifetime, if: :expires_at?
  validate :token_count_within_limit, on: :create
  validate :allowed_ips_are_valid_cidrs

  before_create :generate_token

  def self.authenticate(raw_token)
    return nil if raw_token.blank?

    digest = compute_digest(raw_token)
    active.find_by(token_digest: digest)
  end

  def self.compute_digest(raw_token)
    salt = Rails.application.secret_key_base[0..31]
    Digest::SHA256.base64digest("#{raw_token}#{salt}")
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at > Date.current)
  end

  def expired?
    expires_at.present? && expires_at <= Date.current
  end

  def ip_allowed?(request_ip)
    return true if allowed_ips.blank?

    allowed_ips.any? { |cidr| IPAddr.new(cidr).include?(request_ip) }
  end

  def can?(scope)
    scopes.include?('admin') || scopes.include?(scope.to_s)
  end

  def touch_last_used!
    return if last_used_at.present? && last_used_at > 1.minute.ago

    update_columns(last_used_at: Time.current) # rubocop:disable Rails/SkipsModelValidations -- perf: avoids full save on every API call
  end

  private

  def generate_token
    raw = "#{TOKEN_PREFIX}#{SecureRandom.base58(36)}"
    @raw_token = raw
    self.token_digest = self.class.compute_digest(raw)
    self.token_prefix = raw[0..7]
  end

  def scopes_are_valid
    return if scopes.blank?

    invalid = scopes - VALID_SCOPES
    errors.add(:scopes, "contain invalid values: #{invalid.join(', ')}") if invalid.any?
  end

  def expires_at_within_max_lifetime
    max_date = MAX_LIFETIME_DAYS.days.from_now.to_date
    return if expires_at <= max_date

    errors.add(:expires_at, "must be within #{MAX_LIFETIME_DAYS} days from today")
  end

  def token_count_within_limit
    return unless user

    current_count = user.personal_access_tokens.not_revoked.count
    return if current_count < MAX_TOKENS_PER_USER

    errors.add(:base, "You have reached the maximum of #{MAX_TOKENS_PER_USER} active tokens")
  end

  def allowed_ips_are_valid_cidrs
    return if allowed_ips.blank?

    allowed_ips.each do |cidr|
      IPAddr.new(cidr)
    rescue IPAddr::InvalidAddressError
      errors.add(:allowed_ips, "contain invalid CIDR: #{cidr}")
    end
  end
end
