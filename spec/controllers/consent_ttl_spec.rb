# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationController do
  # REQUIREMENT (AC-8): VULCAN_CONSENT_TTL is a DURATION. A deployment that
  # sets it to "24h" must stop re-prompting for 24 hours after the user
  # acknowledges the banner. The consent notice is a once-per-period
  # acknowledgment, not a recurring interruption.
  #
  # The hazard this pins is in the config template, not the controller:
  # config/vulcan.default.yml is ERB, and casting the value with .to_i there
  # strips the unit suffix before any parser sees it, so "24h" arrives as the
  # Integer 24 and the parser reads it as 24 SECONDS. The same bug class
  # was already fixed once for session_timeout and remember_me_duration, whose
  # comments (config/vulcan.default.yml:34-38) document the required pattern:
  # emit the raw value with to_json and let the consumer parse it.
  #
  # So this spec asserts the template-to-consumer contract end to end: it reads
  # the value the real template emits for a given env var, then drives the real
  # consent_required? gate with it.

  controller do
    skip_before_action :authenticate_user!

    def index
      render plain: consent_required?.to_s
    end
  end

  # The value config/vulcan.default.yml actually emits for a given env var.
  def emitted_ttl(env_value)
    ClimateControl.modify(VULCAN_CONSENT_TTL: env_value) do
      rendered = ERB.new(Rails.root.join('config/vulcan.default.yml').read).result
      YAML.safe_load(rendered, permitted_classes: [Symbol, Proc], aliases: true)
          .dig('defaults', 'consent', 'ttl')
    end
  end

  def with_consent_ttl(env_value)
    allow(Settings).to receive(:consent).and_return(
      OpenStruct.new(enabled: true, ttl: emitted_ttl(env_value))
    )
  end

  describe 'the TTL the config template emits survives its unit suffix' do
    # A suffixed value must reach the consumer as the raw string. If the
    # template casts it to Integer, these are 24/8/30 with the unit lost.
    it 'emits "24h" unchanged rather than the Integer 24' do
      expect(emitted_ttl('24h').to_s).to eq('24h')
    end

    it 'emits "30m" unchanged rather than the Integer 30' do
      expect(emitted_ttl('30m').to_s).to eq('30m')
    end

    it 'still emits a plain-seconds value unchanged' do
      expect(emitted_ttl('3600').to_s).to eq('3600')
    end

    it 'still emits the disabled sentinel unchanged' do
      expect(emitted_ttl(nil).to_s).to eq('0')
    end
  end

  describe 'a suffixed TTL is honoured by the consent gate' do
    # 24h must mean 24 hours. Under the .to_i bug these acknowledgments are
    # 24 seconds old in the gate's eyes, so both cases re-prompt.
    it 'does not re-prompt one hour into a 24h window' do
      with_consent_ttl('24h')
      get :index, session: { consent_acknowledged_at: 1.hour.ago.iso8601 }
      expect(response.body).to eq('false')
    end

    it 'does not re-prompt twenty-three hours into a 24h window' do
      with_consent_ttl('24h')
      get :index, session: { consent_acknowledged_at: 23.hours.ago.iso8601 }
      expect(response.body).to eq('false')
    end

    it 're-prompts once the 24h window has elapsed' do
      with_consent_ttl('24h')
      get :index, session: { consent_acknowledged_at: 25.hours.ago.iso8601 }
      expect(response.body).to eq('true')
    end

    it 'honours a minute suffix: no re-prompt at 10 minutes into a 30m window' do
      with_consent_ttl('30m')
      get :index, session: { consent_acknowledged_at: 10.minutes.ago.iso8601 }
      expect(response.body).to eq('false')
    end

    it 'honours a minute suffix: re-prompts at 31 minutes into a 30m window' do
      with_consent_ttl('30m')
      get :index, session: { consent_acknowledged_at: 31.minutes.ago.iso8601 }
      expect(response.body).to eq('true')
    end
  end

  describe 'plain-seconds and disabled values keep working' do
    # consent.ttl resolves through TimeoutParser with bare_unit: :seconds, so a
    # bare number keeps the plain-seconds meaning this setting has always
    # documented. The default :magnitude mode would read a bare 60 as 60
    # MINUTES, silently redefining every numeric VULCAN_CONSENT_TTL in the
    # field — these two examples pin that it does not.
    it 'treats a bare 3600 as one hour' do
      with_consent_ttl('3600')
      get :index, session: { consent_acknowledged_at: 59.minutes.ago.iso8601 }
      expect(response.body).to eq('false')
    end

    it 'treats a bare 60 as sixty seconds, not sixty minutes' do
      with_consent_ttl('60')
      get :index, session: { consent_acknowledged_at: 2.minutes.ago.iso8601 }
      expect(response.body).to eq('true')
    end

    it 'treats 0 as "never re-prompt" (consent TTL disabled)' do
      with_consent_ttl('0')
      get :index, session: { consent_acknowledged_at: 10.years.ago.iso8601 }
      expect(response.body).to eq('false')
    end
  end
end
