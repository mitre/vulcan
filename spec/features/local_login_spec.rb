require 'rails_helper'

RSpec.describe 'Local Login', type: :feature do
    include LoginHelpers

    context 'when user login is incorrect' do
        let(:u) {create(:user)}
        it 'shows error banner when login credentials are incorrect' do
            hash={'email'=>u.email, 'password'=>'bad_pass'}
            expect { vulcan_sign_in(hash)}
                .not_to change(User, :count)
            
            expect(page)
                .to have_selector('.alert-danger', text: 'Invalid Email or password.')
        end
    end
end
