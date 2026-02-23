# frozen_string_literal: true

# Content Security Policy — mitigates XSS by restricting allowed sources.
# See: https://guides.rubyonrails.org/security.html#content-security-policy-header
#
# Vulcan bundles all JS/CSS locally via esbuild (no CDN dependencies).
# Vue 2 + BootstrapVue use inline styles, so style-src requires 'unsafe-inline'.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self
    policy.frame_src   :none
    policy.base_uri    :self
    policy.form_action :self
  end
end
