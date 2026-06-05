# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dead routes', type: :routing do
  before do
    Rails.application.reload_routes!
  end

  it 'POST /rules/:id/comments is not routable (comments use reviews controller)' do
    expect(post: '/rules/1/comments').not_to be_routable
  end
end
