# frozen_string_literal: true

# app/controllers/concerns/pagy_helper.rb
#
# Pagy defaults to limit: 20 when no params are provided.
# We override to return all records as a single page when
# the client omits both page and limit params.
module PagyHelper
  def pagy(method = :offset, scope, **options)
    page = options[:page] || params[:page]
    limit = options[:limit] || params[:limit]

    if page.blank? && limit.blank?
      count = scope.count(:all)
      return super(method, scope, **options.merge(page: 1, limit: [ count, 1 ].max))
    end

    merged = {}
    merged[:page] = page if page.present?
    merged[:limit] = limit.to_i if limit.present?
    super(method, scope, **options.merge(merged))
  end
end
