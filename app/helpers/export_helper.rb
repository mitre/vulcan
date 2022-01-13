# frozen_string_literal: true

# Helper methods for exports
module ExportHelper
  include ExportConstants

  def export_excel(project)
    # One file for all data types, each data type in a different tab
    workbook = FastExcel.open(constant_memory: true)
    project.components.where(released: true).eager_load(
      rules: [:reviews, :disa_rule_descriptions, :rule_descriptions, :checks,
              :additional_answers, :satisfies, :satisfied_by, {
                srg_rule: %i[disa_rule_descriptions rule_descriptions checks]
              }]
    ).each do |component|
      worksheet = workbook.add_worksheet(component[:version])
      worksheet.auto_width = true
      worksheet.append_row(ExportConstants::DISA_EXPORT_HEADERS)
      last_row_num = 0
      component.rules.each do |rule|
        # fast_excel unfortunately does not provide a method to modify the @last_row_number class variable
        # so it needs to be manually kept track of
        last_row_num += 1
        rule.csv_attributes.each_with_index do |value, col_index|
          worksheet.write_string(last_row_num, col_index, value.to_s, nil)
        end
      end
    end

    workbook.close if workbook.is_open

    workbook
  end
end
