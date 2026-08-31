# frozen_string_literal: true

# app/controllers/v1/admin/analytics_controller.rb
class V1::Admin::AnalyticsController < V1::ApplicationController
  # GET /v1/admin/analytics/overview
  def read_overview
    result = AnalyticsService::Overview.call(
      period: params[:period],
      start_date: params[:start_date],
      end_date: params[:end_date]
    )

    render_json_response(
      status_code: 200,
      message: analytics_message(MessageService::Admin::Analytics::OVERVIEW_RETRIEVED),
      data: result
    )
  end

  private

  def analytics_message(key, **options)
    MessageService::Admin::Analytics.t(key, **options)
  end
end
