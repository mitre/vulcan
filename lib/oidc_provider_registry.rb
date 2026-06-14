# frozen_string_literal: true

# Builds the OIDC provider list for Settings.oidc.providers from environment
# variables. This is the load-time implementation of the "ERB loop over
# VULCAN_OIDC_PROVIDERS" in the multi-provider ADR (§1, §7) — extracted to a
# tested Ruby class instead of raw YAML-ERB so the nested per-provider maps,
# the legacy backward-compat mapping, and key validation are unit-testable.
# Settings remains the single config surface: vulcan.default.yml calls
# OidcProviderRegistry.from_env and consumers only ever read
# Settings.oidc.providers — this class holds no state and is not a second
# config system.
#
# Env families:
#   Registry:  VULCAN_OIDC_PROVIDERS=okta,login_gov  + VULCAN_OIDC_<KEY>_<FIELD>
#   Legacy:    VULCAN_OIDC_PROVIDERS unset           + unprefixed VULCAN_OIDC_<FIELD>
#              (a single provider named `oidc`, only when VULCAN_ENABLE_OIDC)
class OidcProviderRegistry
  # Registry keys are lowercase snake_case: they become the strategy name, the
  # callback path segment, and the identities.provider value — so they must be
  # URL/identifier safe and chosen deliberately.
  KEY_FORMAT = /\A[a-z0-9]+(_[a-z0-9]+)*\z/

  # The single provider name used for the legacy unprefixed env shape.
  LEGACY_NAME = 'oidc'

  def self.from_env(env = ENV)
    new(env).build
  end

  # Transforms a provider config (as built by .from_env / stored in
  # Settings.oidc.providers) into the nested options hash that
  # omniauth_openid_connect expects, ready for
  # `config.omniauth :openid_connect, omniauth_args(provider)` in devise.rb.
  #
  # Two best-practice choices, verified against devise-5.0.4 and
  # omniauth_openid_connect-0.6.1 source:
  #   * Explicit name: and strategy_class: — Devise keys the omniauth config by
  #     options[:name] (so each provider gets its own /users/auth/<name> route)
  #     and uses strategy_class directly, sidestepping the fragile camelize()
  #     lookup of the OpenIDConnect constant. This is the multi-instance pattern.
  #   * send_nonce: true instead of a static nonce: — the strategy generates and
  #     stores its own per-request nonce (new_nonce); there is no :nonce option,
  #     so passing one is dead config.
  #
  # Returns the deduplicated scheme://host origins of all configured providers'
  # issuers. Used by the CSP (form-action / connect-src) and health checks to
  # include every provider's origin, not just the legacy singular one.
  def self.provider_origins
    Array(Settings.oidc&.providers).filter_map do |p|
      uri = URI.parse(p['issuer'].to_s)
      "#{uri.scheme}://#{uri.host}" if uri.host
    rescue URI::InvalidURIError
      nil
    end.uniq
  end

  def self.omniauth_args(provider)
    client_opts = {
      port: provider['port'],
      scheme: provider['scheme'],
      host: provider['host'],
      identifier: provider['client_id'],
      secret: provider['client_secret'],
      redirect_uri: provider['redirect_uri'],
      authorization_endpoint: provider['authorization_endpoint'],
      token_endpoint: provider['token_endpoint'],
      userinfo_endpoint: provider['userinfo_endpoint'],
      jwks_uri: provider['jwks_uri']
    }

    client_opts[:private_key] = load_private_key(provider) if provider['client_auth_method'] == 'jwt_bearer'

    {
      name: provider['name'].to_sym,
      strategy_class: OmniAuth::Strategies::OpenIDConnect,
      scope: %i[openid email profile],
      uid_field: 'sub',
      response_type: :code,
      discovery: provider['discovery'],
      issuer: provider['issuer'],
      client_auth_method: provider['client_auth_method']&.to_sym,
      client_signing_alg: provider['client_signing_alg']&.to_sym,
      send_nonce: true,
      prompt: provider['prompt']&.to_sym,
      acr_values: provider['acr_values'],
      client_options: client_opts
    }
  end

  def self.load_private_key(provider)
    name = provider['name']
    pem = provider['private_key'] || (provider['private_key_path'] && File.read(provider['private_key_path']))

    unless pem
      raise ArgumentError,
            "Provider #{name}: client_auth_method is jwt_bearer but no private key configured. " \
            "Set VULCAN_OIDC_#{name.upcase}_PRIVATE_KEY (inline PEM) or _PRIVATE_KEY_PATH."
    end

    OpenSSL::PKey::RSA.new(pem)
  rescue OpenSSL::PKey::RSAError => e
    raise ArgumentError, "Provider #{name}: failed to parse private key — #{e.message}"
  end

  private_class_method :load_private_key

  # Resolves a provider's human-facing title from the live registry
  # (Settings.oidc.providers). One source of truth shared by the login buttons
  # and the OmniAuth callback flashes, so a configured title (e.g. "Okta") is
  # shown consistently. Falls back to a titleized name for a provider outside
  # the OIDC registry (e.g. :github) or when none is configured.
  def self.title_for(name)
    key = name.to_s
    entry = Array(Settings.oidc&.providers).find { |provider| provider['name'].to_s == key }
    entry ? entry['title'] : key.titleize
  end

  def initialize(env = ENV)
    @env = env
  end

  # Returns an Array of provider config Hashes (string keys, so the JSON
  # embedded in the YAML round-trips predictably). Empty when OIDC is disabled.
  def build
    provider_keys.map { |key| provider_config(key) }
  end

  private

  def legacy_mode?
    @env['VULCAN_OIDC_PROVIDERS'].to_s.strip.empty?
  end

  def provider_keys
    return oidc_enabled? ? [LEGACY_NAME] : [] if legacy_mode?

    @env['VULCAN_OIDC_PROVIDERS'].split(',').map(&:strip).reject(&:empty?).each do |key|
      next if key.match?(KEY_FORMAT)

      raise ArgumentError,
            "Invalid VULCAN_OIDC_PROVIDERS key #{key.inspect}: must be lowercase " \
            'snake_case (a-z, 0-9, underscores) — it becomes the strategy name, ' \
            'callback path, and stored provider value.'
    end
  end

  def oidc_enabled?
    ActiveModel::Type::Boolean.new.cast(@env['VULCAN_ENABLE_OIDC']) || false
  end

  # Field env var for a provider. The legacy `oidc` provider reads unprefixed
  # vars (VULCAN_OIDC_ISSUER_URL); registry providers read
  # VULCAN_OIDC_<KEY>_ISSUER_URL.
  def var(key, field)
    legacy_mode? && key == LEGACY_NAME ? "VULCAN_OIDC_#{field}" : "VULCAN_OIDC_#{key.upcase}_#{field}"
  end

  def fetch(key, field)
    value = @env[var(key, field)]
    value.to_s.empty? ? nil : value
  end

  def provider_config(key)
    {
      'name' => key,
      'title' => provider_title(key),
      'issuer' => fetch(key, 'ISSUER_URL'),
      'client_id' => fetch(key, 'CLIENT_ID'),
      'client_secret' => fetch(key, 'CLIENT_SECRET'),
      'client_auth_method' => fetch(key, 'CLIENT_AUTH_METHOD') || 'secret',
      'client_signing_alg' => fetch(key, 'CLIENT_SIGNING_ALG') || 'RS256',
      'private_key' => fetch(key, 'PRIVATE_KEY'),
      'private_key_path' => fetch(key, 'PRIVATE_KEY_PATH'),
      'acr_values' => fetch(key, 'ACR_VALUES'),
      'prompt' => fetch(key, 'PROMPT'),
      'discovery' => discovery?(key),
      'redirect_uri' => fetch(key, 'REDIRECT_URI'),
      'host' => fetch(key, 'HOST'),
      'port' => fetch(key, 'PORT')&.to_i || 443,
      'scheme' => fetch(key, 'SCHEME') || 'https',
      # Manual endpoint overrides (used only when discovery is off/fails)
      'authorization_endpoint' => fetch(key, 'AUTHORIZATION_URL'),
      'token_endpoint' => fetch(key, 'TOKEN_URL'),
      'userinfo_endpoint' => fetch(key, 'USERINFO_URL'),
      'jwks_uri' => fetch(key, 'JWKS_URI')
    }
  end

  # Title: registry providers use VULCAN_OIDC_<KEY>_TITLE; the legacy provider
  # keeps the existing VULCAN_OIDC_PROVIDER_TITLE var. Falls back to the key.
  def provider_title(key)
    explicit = fetch(key, 'TITLE')
    return explicit if explicit
    return @env['VULCAN_OIDC_PROVIDER_TITLE'] if legacy_mode? && key == LEGACY_NAME && @env['VULCAN_OIDC_PROVIDER_TITLE'].to_s != ''

    key
  end

  # Default true; only false when explicitly set to a false-y value (matches the
  # existing VULCAN_OIDC_DISCOVERY behavior in vulcan.default.yml).
  def discovery?(key)
    raw = fetch(key, 'DISCOVERY')
    return true if raw.nil?

    ActiveModel::Type::Boolean.new.cast(raw) != false
  end
end
