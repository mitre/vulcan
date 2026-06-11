# frozen_string_literal: true

module Import
  module JsonArchive
    module Merge
      # Operator-controlled gate that requires inbound merge archives to
      # carry a signature field on their manifest before the merge engine
      # will accept them.
      #
      # Wired in by MergeOrchestrator: callers invoke +verify!+ (or the
      # non-raising +verify+) with the parsed manifest hash *before*
      # handing it to the Analyzer. When +required?+ is false (the default)
      # this is a no-op, so existing deployments are unaffected.
      #
      # Current scope is PRESENCE ONLY — the gate confirms that
      # +manifest['signature']+ exists and is non-blank. Cryptographic
      # verification (HMAC over the canonicalized manifest payload) is a
      # follow-up and is intentionally NOT performed here. Treat a passing
      # gate as "the archive claims to be signed", not "the signature is
      # valid". Signature verification is tracked as a follow-up on the board.
      class SignatureGate
        # Raised when +require_signed_archives+ is on and the manifest
        # arrives without a +signature+ field. Orchestrator should catch
        # this and surface to the controller as a 4xx rather than enqueueing
        # a MergeJob.
        class MissingSignatureError < StandardError; end

        SETTING_KEY = 'require_signed_archives'

        class << self
          # @return [Boolean] true when the operator has opted in via
          #   Settings.sync.require_signed_archives (or
          #   VULCAN_SYNC_REQUIRE_SIGNED_ARCHIVES).
          def required?
            sync = settings_sync
            return false if sync.nil?

            value = sync.respond_to?(:[]) ? sync[SETTING_KEY] : sync.public_send(SETTING_KEY)
            ActiveModel::Type::Boolean.new.cast(value) == true
          rescue NoMethodError
            false
          end

          # Non-raising variant: returns true on pass, false on fail.
          # Prefer +verify!+ in orchestrator code so the failure carries an
          # exception type that maps cleanly to a controller response.
          #
          # @param manifest [Hash] parsed manifest.json
          # @return [Boolean]
          def verify(manifest)
            verify!(manifest)
            true
          rescue MissingSignatureError
            false
          end

          # @param manifest [Hash] parsed manifest.json
          # @raise [MissingSignatureError] when the gate is on and the
          #   manifest does not carry a non-blank +signature+ field.
          # @return [true] on pass (gate off, or signature present).
          def verify!(manifest)
            return true unless required?

            sig = manifest.is_a?(Hash) ? manifest['signature'] : nil
            return true if sig.is_a?(String) && !sig.strip.empty?

            raise MissingSignatureError,
                  'Archive manifest is missing a signature, but ' \
                  'Settings.sync.require_signed_archives is enabled. ' \
                  'Re-export the archive from a signing-capable instance, ' \
                  'or disable the gate via VULCAN_SYNC_REQUIRE_SIGNED_ARCHIVES=false.'
          end

          private

          def settings_sync
            return nil unless defined?(Settings)

            Settings.respond_to?(:sync) ? Settings.sync : nil
          end
        end
      end
    end
  end
end
