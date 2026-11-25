# frozen_string_literal: true

# Carried patch for activerecord-session_store 2.3.0, which skips the session
# UPDATE when it believes the row is unchanged. Its dirty check compares the
# incoming hash against its own memoized copy, and `Session#to_hash` is a
# shallow dup sharing every nested value with it, so an in-place mutation of a
# nested value is invisible and the write is dropped. Devise's :timeoutable
# hook records activity exactly that way, which left sessions expiring a fixed
# interval after sign-in rather than after the last request.
#
# Comparing serialized bytes is the only comparison that can see it. `super`
# still runs, so this becomes a no-op and can be deleted along with its spec
# once a release carrying the upstream fix lands:
# https://github.com/rails/activerecord-session_store/issues/236
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
