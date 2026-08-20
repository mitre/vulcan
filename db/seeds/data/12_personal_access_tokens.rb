# frozen_string_literal: true

# rubocop:disable Rails/Output
puts 'Seeding personal access tokens...'

return unless Settings.api_tokens&.enabled != false

admin = User.find_by(email: 'admin@example.com')
author = User.find_by(email: 'author@example.com')

if admin && admin.personal_access_tokens.not_revoked.empty?
  token = admin.personal_access_tokens.create!(
    name: 'CI Pipeline',
    scopes: %w[read write],
    expires_at: 90.days.from_now.to_date
  )
  puts "  Admin CI token: #{token.raw_token}"

  admin.personal_access_tokens.create!(
    name: 'Read-only monitoring',
    scopes: %w[read],
    expires_at: 365.days.from_now.to_date,
    allowed_ips: ['127.0.0.0/8']
  )
  puts '  Admin read-only token with IP restriction (127.0.0.0/8)'
end

if author && author.personal_access_tokens.not_revoked.empty?
  author.personal_access_tokens.create!(
    name: 'Script access',
    scopes: %w[read],
    expires_at: 30.days.from_now.to_date
  )
  puts '  Author read-only token'
end

puts "  #{PersonalAccessToken.count} personal access tokens total (#{PersonalAccessToken.where(revoked_at: nil).count} active)"
# rubocop:enable Rails/Output
