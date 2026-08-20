# frozen_string_literal: true

namespace :api_tokens do
  desc 'Revoke personal access tokens unused for longer than the configured idle period'
  task revoke_idle: :environment do
    idle_days = Settings.api_tokens&.auto_revoke_idle_days || 90
    cutoff = idle_days.days.ago

    tokens = PersonalAccessToken
             .where(revoked_at: nil)
             .where('last_used_at IS NOT NULL AND last_used_at < ?', cutoff)

    count = tokens.count
    tokens.find_each do |token|
      token.audit_comment = "Auto-revoked: unused for #{idle_days}+ days" if token.respond_to?(:audit_comment=)
      token.revoke!
    end

    puts "Revoked #{count} idle token(s) (unused since #{cutoff.to_date})"
  end

  desc 'Revoke personal access tokens that have passed their expiration date'
  task revoke_expired: :environment do
    tokens = PersonalAccessToken
             .where(revoked_at: nil)
             .where('expires_at IS NOT NULL AND expires_at <= ?', Date.current)

    count = tokens.count
    tokens.find_each do |token|
      token.audit_comment = 'Auto-revoked: token expired' if token.respond_to?(:audit_comment=)
      token.revoke!
    end

    puts "Revoked #{count} expired token(s)"
  end
end
