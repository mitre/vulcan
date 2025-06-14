# frozen_string_literal: true

# Shared cache context for testing cache functionality
# Based on Rails cache testing best practices
RSpec.shared_context 'with cache', :with_cache do
  let(:memory_store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end
end
