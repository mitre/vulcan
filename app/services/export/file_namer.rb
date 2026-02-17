# frozen_string_literal: true

module Export
  # DRY filename generation for all export types.
  # Centralizes the version/release formatting pattern.
  class FileNamer
    class << self
      def component_filename(component, extension)
        version = component.version ? "V#{component.version}" : ''
        release = component.release ? "R#{component.release}" : ''
        "#{component.prefix}-#{version}#{release}#{extension}"
      end

      def project_filename(project, extension)
        "#{project.name}#{extension}"
      end

      def zip_entry_name(component, extension)
        component_filename(component, extension)
      end

      # Excel worksheet names are limited to 31 characters.
      # Matches the existing ExportHelper pattern exactly.
      def worksheet_name(component)
        name_ending = "-V#{component.version}R#{component.release}-#{component.id}"
        component.name.gsub(/\s+/, '').first(31 - name_ending.length) + name_ending
      end
    end
  end
end
