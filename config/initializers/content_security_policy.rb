# frozen_string_literal: true

# Content Security Policy — mitigates XSS by restricting allowed sources.
# See: https://guides.rubyonrails.org/security.html#content-security-policy-header
# Ref: https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html
#
# Vulcan bundles all JS/CSS locally via esbuild (no CDN dependencies).
# Vue 2 + BootstrapVue use inline styles, so style-src requires 'unsafe-inline'.
# Vue 2 full build (vue.esm.js) compiles templates at runtime using new Function(),
# which requires 'unsafe-eval' in script-src. This is a known Vue 2 limitation
# when templates are embedded in HAML views. Can be removed after Vue 3 migration
# (which uses pre-compiled SFC templates via build step).

Rails.application.configure do
  config.content_security_policy do |policy|
    # Derive OIDC provider origin from issuer URL when OIDC is enabled.
    # OmniAuth redirects the browser to the provider's authorization endpoint
    # via form POST (requires form-action). The navbar also checks GitHub for
    # release updates (requires connect-src).
    oidc_origin = begin
      URI.parse(Settings.oidc.args.issuer).then { |u| "#{u.scheme}://#{u.host}" } if Settings.oidc&.enabled
    rescue URI::InvalidURIError, NoMethodError
      nil
    end

    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self, :unsafe_eval
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self, 'https://api.github.com', *[oidc_origin].compact
    policy.frame_src   :none
    policy.base_uri    :self
    policy.form_action :self, *[oidc_origin].compact
  end
end
