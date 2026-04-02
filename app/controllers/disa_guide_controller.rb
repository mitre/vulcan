# frozen_string_literal: true

##
# Serves DISA process guidance documentation from docs/disa-process/*.md
# within the Vulcan application. Works in airgapped environments.
#
class DisaGuideController < ApplicationController
  before_action :authorize_logged_in

  GUIDE_DIR = Rails.root.join('docs/disa-process')
  PAGES = {
    'overview' => 'Overview',
    'field-requirements' => 'Field Requirements',
    'export-requirements' => 'Export Requirements',
    'intent-form' => 'Intent Form'
  }.freeze

  def show
    page = params[:page] || 'overview'

    unless PAGES.key?(page)
      render plain: 'Page not found', status: :not_found
      return
    end

    file_path = GUIDE_DIR.join("#{page}.md")

    unless file_path.exist?
      render plain: 'Guide content not found', status: :not_found
      return
    end

    markdown_content = file_path.read
    # Rewrite relative attachment links to use the download route
    markdown_content = markdown_content.gsub(
      %r{\[([^\]]+)\]\(attachments/([^)]+)\)},
      '[\1](/disa-guide/attachments/\2)'
    )
    @html_content = Commonmarker.to_html(markdown_content, options: { render: { unsafe: true } })
    @current_page = page
    @pages = PAGES
    @page_title = PAGES[page]
  end

  def attachment
    filename = params[:filename]
    file_path = GUIDE_DIR.join('attachments', filename)

    unless file_path.exist? && file_path.to_s.start_with?(GUIDE_DIR.join('attachments').to_s)
      render plain: 'Attachment not found', status: :not_found
      return
    end

    send_file file_path, disposition: :attachment
  end
end
