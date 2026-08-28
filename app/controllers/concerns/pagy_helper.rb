# app/helpers/pagy_helper.rb
module PagyHelper
  PAGINATION_OFF_VALUES = %w[off all unlimited none].freeze

  def pagy_with_optional_limit(scope)
    limit = params[:limit].to_s.downcase

    if PAGINATION_OFF_VALUES.include?(limit)
      records = scope
      pagy = nil

      return [pagy, records]
    end

    pagy(:offset, scope, limit: params[:limit])
  end
end
