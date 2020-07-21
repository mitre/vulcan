# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { instance_double(User, id: 325) }
  let(:env)     { instance_double('env') }

  context 'with a verified user' do
    let(:warden) { instance_double('warden', user: user) }

    before do
      allow_any_instance_of(ApplicationCable::Connection).to receive(:env).and_return(env)
      allow(env).to receive(:[]).with('warden').and_return(warden)
    end

    it 'successfully connects' do
      connect '/cable', headers: { 'X-USER-ID' => 325 }
      expect(connect.current_user.id).to eq 325
    end
  end

  context 'without a verified user' do
    let(:warden) { instance_double('warden', user: nil) }

    before do
      allow_any_instance_of(ApplicationCable::Connection).to receive(:env).and_return(env)
      allow(env).to receive(:[]).with('warden').and_return(warden)
    end

    it 'rejects connection' do
      expect { connect '/cable' }.to have_rejected_connection
    end
  end
end
