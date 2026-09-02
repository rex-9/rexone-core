# frozen_string_literal: true

module SortableHelper
  def sort(scope, columns:, default_column: columns.first, default_direction: SortConstants::Order::DESC)
    sort_by = params[:sort_by].to_s.presence
    sort_order = params[:sort_order].to_s.downcase
    direction = sort_order == SortConstants::Order::ASC ? :asc : :desc

    if sort_by.present? && columns.map(&:to_s).include?(sort_by)
      case sort_by
      when "user_name"
        scope.left_joins(:user).order(
          User.arel_table[:name].public_send(direction),
          User.arel_table[:username].public_send(direction)
        )
      when "product_name"
        scope.left_joins(:product).order(
          Payment::Product.arel_table[:name].public_send(direction)
        )
      when "message_count"
        scope.left_joins(:messages)
             .group(scope.klass.arel_table[:id])
             .order(Chat::Message.arel_table[:id].count.public_send(direction))
      else
        scope.order(sort_by.to_sym => direction)
      end
    else
      fallback_dir = default_direction.to_s == SortConstants::Order::ASC ? :asc : :desc
      scope.order(default_column.to_sym => fallback_dir)
    end
  end
end
