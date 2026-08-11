# frozen_string_literal: true

require 'rails_helper'

##
# The hand-built guide pipeline is retired: its URLs live on as permanent
# redirects into the documentation site, and every target must actually
# resolve there — a redirect onto a 404 retires nothing. The maps below
# enumerate every URL the old pipeline served: each page, the default page,
# the legacy slug it already redirected, and all three attachment files its
# link rewrite exposed for download.
#
RSpec.describe 'DISA guide redirects' do
  let_it_be(:user) { create(:user) }

  before(:all) { DocsSiteHelpers.require_built_site! }

  before { Rails.application.reload_routes! }

  page_redirects = {
    '/disa-guide' => '/docs/disa-process/overview',
    '/disa-guide/overview' => '/docs/disa-process/overview',
    '/disa-guide/vendor-stig-process-guide' => '/docs/disa-process/vendor-stig-process-guide',
    '/disa-guide/vendor-stig-process-guide-v4r1' => '/docs/disa-process/vendor-stig-process-guide',
    '/disa-guide/field-requirements' => '/docs/disa-process/field-requirements',
    '/disa-guide/export-requirements' => '/docs/disa-process/export-requirements',
    '/disa-guide/intent-form' => '/docs/disa-process/intent-form'
  }.freeze

  attachment_redirects = {
    '/disa-guide/attachments/U_Vendor_STIG_Intent_Form.pdf' =>
      '/docs/attachments/U_Vendor_STIG_Intent_Form.pdf',
    '/disa-guide/attachments/U_Vendor_STIG_Process_Guide_V4R3.docx' =>
      '/docs/attachments/U_Vendor_STIG_Process_Guide_V4R3.docx',
    '/disa-guide/attachments/vendor-stig-process-milestones.png' =>
      '/docs/attachments/vendor-stig-process-milestones.png'
  }.freeze

  all_redirects = page_redirects.merge(attachment_redirects).freeze

  describe 'every previously served guide path redirects to its page on the documentation site' do
    all_redirects.each do |old_url, target|
      it "permanently redirects #{old_url}" do
        get old_url

        expect(response).to redirect_to(target)
        expect(response).to have_http_status(:moved_permanently)
      end
    end
  end

  describe 'every redirect target resolves on the served site' do
    before { sign_in user }

    all_redirects.values.uniq.each do |target|
      it "serves #{target}" do
        get target

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
