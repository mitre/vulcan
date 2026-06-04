# frozen_string_literal: true

##
# Serves DISA process guidance documentation from docs/disa-process/*.md
# within the Vulcan application. Works in airgapped environments.
#
class DisaGuideController < ApplicationController
  before_action :authorize_logged_in

  GUIDE_DIR = Rails.root.join('docs/disa-process')

  PAGE_SECTIONS = [
    {
      label: 'Reference',
      pages: {
        'vendor-stig-process-guide-v4r1' => 'Vendor STIG Process Guide (V4R1)'
      }
    },
    {
      label: 'Guides',
      pages: {
        'overview' => 'Process Overview',
        'field-requirements' => 'Field Requirements by Status',
        'export-requirements' => 'Export Requirements',
        'intent-form' => 'Intent Form & Questionnaire'
      }
    }
  ].freeze

  PAGES = PAGE_SECTIONS.flat_map { |s| s[:pages].to_a }.to_h.freeze

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
    # Convert ::: callouts to HTML before markdown rendering
    markdown_content = convert_callouts(markdown_content)
    # Rewrite relative attachment links to use the download route
    markdown_content = markdown_content.gsub(
      %r{\[([^\]]+)\]\(attachments/([^)]+)\)},
      '[\1](/disa-guide/attachments/\2)'
    )
    rendered_html = Commonmarker.to_html(markdown_content, options: {
                                          render: { unsafe: true },
                                          extension: { header_ids: '' }
                                        })
    doc = Nokogiri::HTML.fragment(rendered_html)
    @toc = extract_toc(doc)
    @html_content = ActionController::Base.helpers.sanitize(
      doc.to_html,
      attributes: Rails::HTML::SafeListSanitizer.allowed_attributes + %w[id aria-hidden role]
    )
    @current_page = page
    @pages = PAGES
    @page_sections = PAGE_SECTIONS
    @page_title = PAGES[page]
  end

  def attachment
    filename = File.basename(params[:filename].to_s)
    file_path = GUIDE_DIR.join('attachments', filename)

    unless file_path.exist?
      render plain: 'Attachment not found', status: :not_found
      return
    end

    send_file file_path, disposition: :attachment
  end

  private

  CALLOUT_VARIANTS = {
    'info' => 'info',
    'warning' => 'warning',
    'tip' => 'success',
    'danger' => 'danger'
  }.freeze

  def convert_callouts(markdown)
    markdown.gsub(/^::: (\w+)\s*(.*?)\n(.*?)^:::\s*$/m) do
      type = Regexp.last_match(1)
      title = Regexp.last_match(2)&.strip
      body = Regexp.last_match(3).strip
      variant = CALLOUT_VARIANTS[type] || 'secondary'
      rendered_body = Commonmarker.to_html(body, options: { render: { unsafe: true } })
      header = title.present? ? "<strong class=\"d-block mb-2\">#{title}</strong>" : ''
      "\n<div class=\"alert alert-#{variant} disa-guide-callout\" role=\"alert\">\n#{header}#{rendered_body}\n</div>\n"
    end
  end

  def extract_toc(doc)
    toc = []
    doc.css('h2, h3').each do |heading|
      anchor = heading.at_css('a.anchor[id]')
      next unless anchor

      toc << { level: heading.name[1].to_i, text: heading.text.strip, id: anchor['id'] }
    end
    toc
  end
end
