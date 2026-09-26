# frozen_string_literal: true

# app/controllers/v1/admin/ai/runs_controller.rb
class V1::Admin::Ai::RunsController < V1::ApplicationController
  before_action :set_run, only: %i[show]

  def permission_resource_name
    IamConstants::Resource::AI_RUNS
  end

  # GET /v1/admin/ai/runs
  def index
    filters = list_params
    runs = Ai::RunService.list(filters.except(:limit, :page, :sort_by, :sort_order))
    runs = sort(runs, columns: SortConstants::Columns::AI_RUN)
    pagy, records = pagy(:offset, runs, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::RUNS_FETCHED),
      **Ai::RunSerializer.paginated(records, pagy)
    )
  end

  # GET /v1/admin/ai/runs/:id
  def show
    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::RUN_FETCHED),
      data: Ai::RunSerializer.record(@run)
    )
  end

  private

  def list_params
    params.permit(:feature, :status, :provider, :model, :profile_id, :user_id, :search, :sort_by, :sort_order, :limit, :page)
  end

  def set_run
    @run = Ai::RunService.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: ai_message(MessageService::Ai::NOT_FOUND),
      error: ai_message(MessageService::Ai::NOT_FOUND)
    )
  end

  def ai_message(key, **options)
    MessageService::Ai.t(key, **options)
  end
end
