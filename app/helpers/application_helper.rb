# frozen_string_literal: true

# This module handles items that we use across multiple controllers
# and views throughout the application
module ApplicationHelper
  # This allows us access to the _path variables inside the application
  include Rails.application.routes.url_helpers

  # Build the links shown to users in the navigation bar
  def base_navigation
    nav_links = [
      { icon: 'mdi-folder-open-outline', name: 'Projects', link: projects_path },
      { icon: 'mdi-stamper', name: 'Released Components', link: components_path },
      { icon: 'mdi-folder', name: 'STIGs', link: stigs_path },
      { icon: 'mdi-folder', name: 'SRGs', link: srgs_path }
    ]

    if current_user&.admin? || Settings.project.create_permission_enabled
      nav_links.insert(1, { icon: 'mdi-timer-sand', name: 'Start New Project', link: new_project_path })
    end

    nav_links
  end

  # Get the latest release changes to display on the landing page
  def latest_release_details
    changelog_path = Rails.root.join('CHANGELOG.md')
    release_details = ''

    begin
      File.open(changelog_path, 'r') do |file|
        line = file.gets
        while line
          if line.start_with?('## Vulcan v')
            # Found the beginning of a release, start reading details
            release_details = line
            line = file.gets
            while line && !line.start_with?('## Vulcan v')
              release_details += line
              line = file.gets
            end
            # Exit the loop once the latest release details have been read
            break
          end
          line = file.gets
        end
      end
    rescue StandardError => e
      Rails.logger.error "Unable to read latest release: #{e.message}"
    end

    release_details
  end

  def markdown_to_html(text)
    options = %i[hard_wrap autolink no_intra_emphasis fenced_code_blocks]
    Markdown.new(text, *options).to_html
  end
end
