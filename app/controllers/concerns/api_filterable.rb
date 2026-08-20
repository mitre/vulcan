# frozen_string_literal: true

# Pagination, sorting, and response envelope for API list endpoints.
module ApiFilterable
  extend ActiveSupport::Concern
  include Pagy::Method

  def paginate(scope, **)
    pagy(:offset, scope, **)
  end

  def pagy_response(pagy_obj, records, **extra)
    {
      rows: records,
      pagination: {
        page: pagy_obj.page,
        per_page: pagy_obj.limit,
        total: pagy_obj.count
      }
    }.merge(extra)
  end

  def apply_sort(scope, allowed:)
    field = params[:sort]
    return scope unless field.present? && allowed.include?(field)

    direction = %w[asc desc].include?(params[:order]) ? params[:order] : 'asc'
    scope.order(field => direction)
  end
end
