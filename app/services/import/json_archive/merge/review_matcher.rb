# frozen_string_literal: true

require 'digest'

module Import
  module JsonArchive
    module Merge
      # Matches two sets of normalized review hashes by a composite key
      # (rule_id, created_at, comment_digest) and partitions them into
      # matched / only_ours / only_theirs, with a separate collisions list
      # for degenerate groups that share the full key (same rule, same
      # second, same comment text).
      #
      # Inputs are plain Hashes with string keys — no AR objects — so this
      # is a pure-computation class with no DB access.
      class ReviewMatcher
        MatchResult = Struct.new(:matched, :only_ours, :only_theirs, :collisions, keyword_init: true)

        # Truncated SHA-256 over NFC-normalized comment text. 64 bits is
        # adequate against accidental collisions at our scale; degenerate
        # cases (same rule, same second, same text) are caught by the
        # collisions accumulator and surfaced as MergePlan warnings.
        def self.digest(comment)
          normalized = (comment || '').to_s.unicode_normalize(:nfc)
          Digest::SHA256.hexdigest(normalized.encode('UTF-8'))[0..15]
        end

        # @param ours_reviews [Array<Hash>] normalized review hashes (string keys)
        # @param theirs_reviews [Array<Hash>] same shape
        # @param manifest_version [String] '1.0' triggers second-precision
        #   created_at normalization so legacy archives match against
        #   microsecond-precision exports
        def initialize(ours_reviews:, theirs_reviews:, manifest_version: '1.1')
          @ours = ours_reviews
          @theirs = theirs_reviews
          @manifest_version = manifest_version
        end

        def match
          ours_grouped = group_by_key(@ours)
          theirs_grouped = group_by_key(@theirs)

          matched = []
          collisions = []
          only_ours = []
          only_theirs = []

          (ours_grouped.keys | theirs_grouped.keys).each do |key|
            ours_grp = ours_grouped[key] || []
            theirs_grp = theirs_grouped[key] || []

            if ours_grp.empty?
              only_theirs.concat(theirs_grp)
            elsif theirs_grp.empty?
              only_ours.concat(ours_grp)
            elsif ours_grp.size == 1 && theirs_grp.size == 1
              matched << { ours: ours_grp.first, theirs: theirs_grp.first }
            else
              pair_degenerate(key, ours_grp, theirs_grp, matched, only_ours, only_theirs, collisions)
            end
          end

          MatchResult.new(
            matched: matched,
            only_ours: only_ours,
            only_theirs: only_theirs,
            collisions: collisions
          )
        end

        private

        def group_by_key(reviews)
          reviews.group_by { |r| composite_key(r) }
        end

        def composite_key(review)
          [
            review.fetch('rule_id'),
            normalized_created_at(review['created_at']),
            self.class.digest(review['comment'])
          ].join('::')
        end

        # v1.0 archives carry second-precision created_at; current exports
        # carry microsecond. Normalize both sides to second precision in v1.0
        # mode so a legacy archive matches against a fresh export of the same
        # review.
        def normalized_created_at(created_at)
          return created_at unless legacy_format?
          return created_at if created_at.nil?

          # ISO 8601: truncate at the dot (or pass through if already integer-second)
          created_at.to_s.sub(/\.\d+/, '')
        end

        def legacy_format?
          @manifest_version == '1.0'
        end

        # Same key on both sides with >1 review → tiebreak by external_id
        # position (ascending). Unpaired extras spill into only_ours /
        # only_theirs; the collision is always logged so MergePlan can
        # surface a warning even when fully paired.
        def pair_degenerate(key, ours_grp, theirs_grp, matched, only_ours, only_theirs, collisions)
          collisions << { key: key, members: ours_grp + theirs_grp }

          ours_sorted = ours_grp.sort_by { |r| r.fetch('external_id', 0).to_i }
          theirs_sorted = theirs_grp.sort_by { |r| r.fetch('external_id', 0).to_i }

          pair_count = [ours_sorted.size, theirs_sorted.size].min
          pair_count.times do |i|
            matched << { ours: ours_sorted[i], theirs: theirs_sorted[i] }
          end
          only_ours.concat(ours_sorted[pair_count..]) if ours_sorted.size > pair_count
          only_theirs.concat(theirs_sorted[pair_count..]) if theirs_sorted.size > pair_count
        end
      end
    end
  end
end
