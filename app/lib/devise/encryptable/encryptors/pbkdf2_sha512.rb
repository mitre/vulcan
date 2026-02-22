# frozen_string_literal: true

require 'openssl'

module Devise
  module Encryptable
    module Encryptors
      # PBKDF2-SHA512 encryptor for FIPS 140-2 compliance.
      # Uses OpenSSL::KDF.pbkdf2_hmac which delegates to the system's
      # OpenSSL library. On FIPS-enabled systems (e.g., RHEL with
      # fips-mode-setup --enable), this uses the FIPS-validated module.
      #
      # Password format: $pbkdf2-sha512$<iterations>$<base64-salt>$<base64-hash>
      # This self-describing format enables future iteration upgrades.
      class Pbkdf2Sha512 < Base
        HASH_LENGTH = 64 # 512 bits
        ALGORITHM = 'SHA512'

        def self.digest(password, stretches, salt, pepper)
          combined_pepper = "#{password}#{pepper}"
          hash = OpenSSL::KDF.pbkdf2_hmac(
            combined_pepper,
            salt: salt,
            iterations: stretches,
            length: HASH_LENGTH,
            hash: ALGORITHM
          )
          "$pbkdf2-sha512$#{stretches}$#{Base64.strict_encode64(salt)}$#{Base64.strict_encode64(hash)}"
        end

        def self.compare(encrypted_password, password, stretches, salt, pepper)
          new_hash = digest(password, stretches, salt, pepper)
          ActiveSupport::SecurityUtils.secure_compare(encrypted_password, new_hash)
        end
      end
    end
  end
end
