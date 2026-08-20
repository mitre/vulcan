# frozen_string_literal: true

module RuboCop
  module Cop
    module Vulcan
      # Prevents overriding the global `refind: true` default on `let_it_be`.
      #
      # The project configures `TestProf::LetItBe` with
      # `config.default_modifiers[:refind] = true` (in rails_helper.rb) so
      # every `let_it_be` record gets a fresh ActiveRecord instance per
      # example via `Model.unscoped.find(id)`. This prevents in-memory state
      # leakage between examples — the root cause of non-deterministic
      # parallel test failures where one example's mutations persist on the
      # shared Ruby object even though the DB row is rolled back.
      #
      # Explicitly passing `refind: false` defeats this safety net. If a
      # test truly needs the shared in-memory object (rare), document WHY
      # with an inline comment.
      #
      # @example Bad
      #   let_it_be(:user, refind: false) { create(:user) }
      #
      # @example Good — uses global default
      #   let_it_be(:user) { create(:user) }
      #
      # @example Good — explicit refind: true (redundant but not harmful)
      #   let_it_be(:user, refind: true) { create(:user) }
      class LetItBeRefind < Base
        MSG = 'Do not override the global `refind: true` default. ' \
              'Removing `refind: false` lets the global config provide a fresh AR instance per example, ' \
              'preventing in-memory state leakage. See rails_helper.rb TestProf::LetItBe configuration.'

        # Match: let_it_be(:name, refind: false) { ... }
        def_node_matcher :let_it_be_refind_false?, <<~PATTERN
          (send nil? :let_it_be _name (hash <(pair (sym :refind) false) ...>) ...)
        PATTERN

        def on_send(node)
          return unless let_it_be_refind_false?(node)

          add_offense(node)
        end
      end
    end
  end
end
