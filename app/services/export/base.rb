# frozen_string_literal: true

module Export
  # Orchestrator for the export system.
  # Resolves mode + formatter, iterates components, produces Result(s).
  #
  # Usage:
  #   Export::Base.new(exportable: component, mode: :working_copy, format: :csv).call
  #   Export::Base.new(exportable: project, mode: :working_copy, format: :csv).call
  #   Export::Base.new(exportable: project, mode: :working_copy, format: :csv, component_ids: [1,2]).call
  #   Export::Base.new(exportable: [comp1, comp2], mode: :working_copy, format: :csv).call
  #   Export::Base.new(exportable: project, mode: :working_copy, format: :excel).call
  class Base
    def initialize(exportable:, mode:, format:, component_ids: nil, zip_filename: nil, formatter_options: {})
      raise ArgumentError, 'exportable cannot be nil' if exportable.nil?

      unless Registry.valid?(mode, format)
        raise Registry::InvalidCombination,
              "Invalid export combination: #{mode} + #{format}"
      end

      @exportable = exportable
      @mode = Registry.mode_class(mode).new
      @formatter = Registry.formatter_class(format).new
      @component_ids = component_ids
      @zip_filename = zip_filename
      @formatter_options = formatter_options
    end

    def call
      components = resolve_components

      if @formatter.batch_generate?
        export_batch(components)
      elsif @formatter.component_based?
        export_component_based(components)
      elsif @formatter.multi_sheet?
        export_as_workbook(components)
      else
        results = components.map { |component| export_component(component) }
        zip_name = @zip_filename || default_zip_filename
        Packager.package(results, zip_filename: zip_name)
      end
    end

    private

    def resolve_components
      case @exportable
      when Component
        [@exportable]
      when Project
        scope = @exportable.components
        scope = scope.where(id: @component_ids) if @component_ids.present?
        scope.to_a
      when Array
        # Direct array of components (e.g., from bulk_export)
        @exportable
      else
        raise ArgumentError, "Unsupported exportable type: #{@exportable.class}"
      end
    end

    def default_zip_filename
      if @exportable.respond_to?(:name)
        FileNamer.project_filename(@exportable, '.zip')
      else
        'export.zip'
      end
    end

    # Batch path: all components passed at once to the formatter (InSpec).
    # Produces a single archive with subdirectories per component.
    def export_batch(components)
      pairs = components.sort_by(&:id).map do |component|
        rules = load_rules(component)
        scoped = @mode.rule_scope(rules)
        { component: component, rules: scoped }
      end

      data = @formatter.generate_batch(component_rule_pairs: pairs, **@formatter_options)
      filename = @zip_filename || default_zip_filename

      Result.new(data: data, filename: filename, content_type: @formatter.content_type)
    end

    # Component-based path: each component is processed individually (XCCDF).
    # Packager zips multiple results, passes through a single one.
    def export_component_based(components)
      results = components.sort_by(&:id).map do |component|
        rules = load_rules(component)
        scoped = @mode.rule_scope(rules)
        data = @formatter.generate_from_component(component: component, rules: scoped)
        filename = FileNamer.component_filename(component, @formatter.file_extension)

        Result.new(data: data, filename: filename, content_type: @formatter.content_type)
      end

      zip_name = @zip_filename || default_zip_filename
      Packager.package(results, zip_filename: zip_name)
    end

    # Multi-sheet path: aggregates all components into a single workbook.
    # Used by ExcelFormatter where each component becomes one worksheet.
    def export_as_workbook(components)
      sheets = components.sort_by(&:id).map do |component|
        rows = build_rows(component)
        { name: FileNamer.worksheet_name(component), headers: @mode.headers, rows: rows }
      end

      data = @formatter.generate_workbook(sheets: sheets)
      filename = default_workbook_filename

      Result.new(data: data, filename: filename, content_type: @formatter.content_type)
    end

    # Single-file-per-component path: each component is one Result.
    # Packager zips multiple results, passes through a single one.
    def export_component(component)
      rows = build_rows(component)
      data = @formatter.generate(headers: @mode.headers, rows: rows)
      filename = FileNamer.component_filename(component, @formatter.file_extension)

      Result.new(data: data, filename: filename, content_type: @formatter.content_type)
    end

    def build_rows(component)
      rules = load_rules(component)
      scoped_rules = @mode.rule_scope(rules)

      scoped_rules.order(:version, :rule_id).map do |rule|
        exportable_rule = ExportableRule.new(rule)
        @mode.columns.map do |key|
          value = exportable_rule.value_for(key)
          @mode.transform_value(key, value, exportable_rule)
        end
      end
    end

    def load_rules(component)
      component.rules.eager_load(*@mode.eager_load_associations)
    end

    def default_workbook_filename
      if @exportable.respond_to?(:name)
        FileNamer.project_filename(@exportable, @formatter.file_extension)
      else
        "export#{@formatter.file_extension}"
      end
    end
  end
end
