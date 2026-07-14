# frozen_string_literal: true

##
# regression guard for the canonical
# toast response contract.
#
# Every JSON mutation endpoint that surfaces a
# user-facing toast MUST return the canonical shape:
#
#   { "toast": { "title": "...", "message": ["..."], "variant": "..." } }
#
# The frontend AlertMixin's string-handling branch was removed in
# commit b671593. Any controller now returning {toast: 'string'}
# silently fails — AlertMixin falls through to its error path and
# the user sees no toast.
#
# The architecture-review agent caught a 14-site regression where this
# contract was missed (fixed in 906941d). This shared example exists
# so future request specs can opt in with one line:
#
#   context 'when the action triggers a toast' do
#     before { post '/things', params: ... }
#     it_behaves_like 'a canonical toast response'
#   end
#
# The example asserts on the most recent `response` — so the
# preceding `before` (or example setup) must have fired the request
# whose body is being checked.
RSpec.shared_examples 'a canonical toast response' do
  it 'returns the canonical toast object shape', :aggregate_failures do
    json = response.parsed_body
    expect(json).to have_key('toast'),
                    'Response missing top-level "toast" key — every JSON mutation returns the canonical toast'
    expect(json['toast']).to be_a(Hash),
                             "Expected toast to be a Hash, got #{json['toast'].class}: " \
                             "#{json['toast'].inspect}. The string-toast shape was removed " \
                             '(b671593) — the frontend will silently ' \
                             'drop string toasts. Use ApplicationController#render_toast or ' \
                             'inline {toast: {title:, message: [], variant:}} hash.'
    expect(json['toast']).to include('title', 'message', 'variant'),
                             "toast object missing required keys (have: #{json['toast'].keys.inspect})"
    expect(json['toast']['title']).to be_a(String).and(be_present)
    expect(json['toast']['message']).to be_an(Array),
                                        'Expected message to be an Array (the canonical ' \
                                        "shape), got #{json['toast']['message'].class}: " \
                                        "#{json['toast']['message'].inspect}"
    expect(%w[success warning danger info]).to include(json['toast']['variant']),
                                               "Unknown toast variant #{json['toast']['variant'].inspect} — " \
                                               'allowed: success, warning, danger, info'
  end
end
