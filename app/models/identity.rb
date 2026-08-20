# frozen_string_literal: true

# A linked external identity (provider + uid) for a user. One user may hold
# multiple identities (e.g. Okta + login.gov). The link key is (provider, uid);
# email is stored for display/audit only and is NOT the link key.
class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  audited associated_with: :user
end
