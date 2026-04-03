# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserMailer do
  it 'does not override ApplicationMailer default from address' do
    from_lines = grep_config('app/mailers/user_mailer.rb', /default\s+from:/)

    expect(from_lines).to be_empty,
                          "UserMailer should not override `default from:` — inherit from ApplicationMailer:\n" \
                          "#{from_lines.map(&:strip).join("\n")}"
  end

  it 'inherits ApplicationMailer from address' do
    # UserMailer should not define its own :from — it should inherit from ApplicationMailer.
    own_defaults = UserMailer.instance_variable_get(:@_default_mail_params) || {}
    expect(own_defaults).not_to have_key(:from),
                                'UserMailer should not have its own default :from (inherits from ApplicationMailer)'
  end
end
