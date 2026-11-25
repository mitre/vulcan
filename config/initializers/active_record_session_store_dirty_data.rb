# frozen_string_literal: true

# Carried upstream patch for activerecord-session_store 2.3.0.
#
# THE DEFECT
#
# 2.3.0 added a dirty check that skips the UPDATE when the session is
# unchanged (lib/action_dispatch/session/active_record_store.rb):
#
#   record.data = session_data
#   return sid unless record.changed? || record.new_record?
#
# and the dirty flag it relies on (lib/active_record/session_store/session.rb):
#
#   def data=(data)
#     attribute_will_change!(@@data_column_name) if data != self.data
#     @data = data
#   end
#
# `self.data` memoizes the deserialized hash in `@data`, and the hash handed
# to `data=` is `ActionDispatch::Request::Session#to_hash`, a SHALLOW dup of
# the same hash. Its nested values are therefore the SAME objects as the ones
# in `@data`. So for any in-place mutation of a nested value, `data` and
# `self.data` are the same object graph, `data != self.data` is false,
# `attribute_will_change!` never fires, `changed?` stays false, and the write
# is silently discarded.
#
# Devise's :timeoutable hook does exactly that nested mutation:
#
#   warden.session(scope)['last_request_at'] = Time.now.utc.to_i
#   # => session['warden.user.user.session']['last_request_at'] = ...
#
# so `last_request_at` was recomputed and thrown away on every request, and
# sessions expired a fixed `Devise.timeout_in` after SIGN-IN instead of after
# the last activity. Any other nested session state is dropped the same way.
#
# THE FIX
#
# A dirty check on session data cannot be made correct by comparing object
# graphs, because the incoming graph is (partly) the memoized one. The only
# sound question is "do the bytes about to be stored differ from the bytes
# already stored?", which is what this compares. That keeps the optimisation
# 2.3.0 was after (no UPDATE when the session genuinely did not change) while
# catching in-place mutations. It errs toward writing: if serialization is
# ever non-deterministic for an unchanged hash, the cost is a redundant
# UPDATE, never a lost session write.
#
# `super` is still called so the gem keeps whatever it detects on its own;
# `attribute_will_change!` is idempotent. When upstream fixes `data=`, this
# module becomes a no-op and can be deleted along with its spec.
#
# Cost: one single-row UPDATE on `sessions` per authenticated request — the
# behaviour of every release of this gem up to and including 2.2.0, which
# saved unconditionally.
module ActiveRecordSessionStoreDirtyData
  def data=(new_data)
    column = self.class.data_column_name
    attribute_will_change!(column) if self.class.serialize(new_data) != read_attribute(column)
    super
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::SessionStore::Session.prepend(ActiveRecordSessionStoreDirtyData)
end
