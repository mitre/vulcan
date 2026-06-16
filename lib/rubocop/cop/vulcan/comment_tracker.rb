# frozen_string_literal: true

module RuboCop
  module Cop
    module Vulcan
      # Detects internal issue-tracker references in source code comments.
      #
      # Tracker IDs (e.g. board-prefix-id patterns) are
      # project-management artifacts that belong in commit messages and
      # pull request descriptions — not in committed source. They leak
      # internal tooling details into public repositories and become
      # meaningless as boards are reorganized and cards renumbered.
      #
      # Auto-correction strips the tracker reference while preserving
      # the surrounding technical comment. When stripping leaves the
      # comment empty, the entire comment line is removed.
      #
      # @note This cop is designed to be portable across MITRE projects.
      #   Add new tracker prefixes to +TRACKER_RE+ as needed.
      #
      # @safety
      #   Safe. Only modifies comment text — never touches executable code.
      #   Standalone empty-comment removal uses +range_by_whole_lines+ to
      #   cleanly delete the full line including indentation and newline.
      #   Inline empty-comment removal uses +range_with_surrounding_space+
      #   to strip trailing whitespace without affecting the code portion.
      #
      # rubocop:disable Vulcan/CommentTracker
      # @example Standalone comment with leading reference
      #   # bad
      #   # vulcan-clean-abc: fix this later
      #
      #   # good
      #   # fix this later
      #
      # @example Inline comment (entire comment is a reference)
      #   # bad
      #   x = 1 # vulcan-v3.x-def
      #
      #   # good
      #   x = 1
      #
      # @example Parenthesized reference with section number
      #   # bad
      #   # Batch counts via GROUP BY (vulcan-v3.x-73z.9 §4.2).
      #
      #   # good
      #   # Batch counts via GROUP BY.
      #
      # @example Trailing reference after sentence
      #   # bad
      #   # DB ids changed between merges. vulcan-v3.x-480.7.
      #
      #   # good
      #   # DB ids changed between merges.
      # rubocop:enable Vulcan/CommentTracker
      #
      # @see https://docs.rubocop.org/rubocop/development.html Writing Custom Cops
      class CommentTracker < Base
        include RangeHelp
        extend AutoCorrector

        MSG = 'Do not reference tracker IDs in source comments.'

        # Matches internal tracker prefixes followed by a card identifier.
        # Covers the legacy long-form board prefixes (vulcan-clean-,
        # vulcan-v2.x-, vulcan-v3.x-) AND the current short-form board
        # prefix (v2-, v3-). Add new prefixes here when the board prefix
        # changes or when adopting this cop in other projects.
        TRACKER_RE = /\b(?:vulcan-(?:v3\.x|v2\.x|clean)|v[23])-[\w.]+(?:\s*§[\d.]+)?/

        # Called once per file before AST walking. Comments are not AST
        # nodes, so we iterate +processed_source.comments+ directly —
        # the same pattern used by +Style::CommentAnnotation+ in core.
        #
        # @return [void]
        def on_new_investigation
          processed_source.comments.each do |comment|
            next unless comment.text.match?(TRACKER_RE)

            add_offense(comment) do |corrector|
              autocorrect(corrector, comment)
            end
          end
        end

        private

        # Strips the tracker reference from the comment text, then either
        # replaces the comment with the cleaned text or removes it entirely
        # if nothing meaningful remains.
        #
        # @param corrector [RuboCop::Cop::Corrector]
        # @param comment   [Parser::Source::Comment]
        # @return [void]
        def autocorrect(corrector, comment)
          new_text = strip_tracker(comment.text)

          if empty_comment?(new_text)
            remove_comment(corrector, comment)
          else
            corrector.replace(comment, new_text)
          end
        end

        # Removes tracker patterns from comment text in priority order:
        # parenthesized refs first, then leading refs with colon/comma,
        # then trailing bare refs.
        #
        # @param text [String] the full comment text including +#+ prefix
        # @return [String] cleaned comment text
        STRIP_PAREN = /\s*\(#{TRACKER_RE}\)/o
        STRIP_LEADING = /#{TRACKER_RE}[,:]\s*/o
        STRIP_TRAILING = /\s*#{TRACKER_RE}\.?/o
        private_constant :STRIP_PAREN, :STRIP_LEADING, :STRIP_TRAILING

        def strip_tracker(text)
          text
            .gsub(STRIP_PAREN, '')
            .gsub(STRIP_LEADING, '')
            .gsub(STRIP_TRAILING, '')
            .gsub(/\s{2,}/, ' ')
            .rstrip
        end

        # @param text [String]
        # @return [Boolean] true when the comment contains only +#+ and whitespace
        def empty_comment?(text)
          text.match?(/\A#\s*\z/) || text == '#'
        end

        # Removes a comment cleanly, distinguishing standalone comments
        # (delete the whole line) from inline comments (delete comment +
        # preceding whitespace but not the code or newline).
        #
        # Pattern borrowed from +Layout::EmptyComment+ in RuboCop core.
        #
        # @param corrector [RuboCop::Cop::Corrector]
        # @param comment   [Parser::Source::Comment]
        # @return [void]
        def remove_comment(corrector, comment)
          range = if inline_comment?(comment)
                    range_with_surrounding_space(comment.source_range, newlines: false)
                  else
                    range_by_whole_lines(comment.source_range, include_final_newline: true)
                  end
          corrector.remove(range)
        end

        # A comment is inline if there is non-whitespace content before it
        # on the same source line (e.g. +x = 1 # comment+).
        #
        # @param comment [Parser::Source::Comment]
        # @return [Boolean]
        def inline_comment?(comment)
          source_line = comment.source_range.source_line
          source_line[0...comment.source_range.column].match?(/\S/)
        end
      end
    end
  end
end
