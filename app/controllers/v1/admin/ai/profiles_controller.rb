# frozen_string_literal: true

# app/controllers/v1/admin/ai/profiles_controller.rb
class V1::Admin::Ai::ProfilesController < V1::ApplicationController
  before_action :set_profile, only: %i[show update destroy]

  # GET /v1/admin/ai/profiles
  def index
    profiles = Ai::ProfileService.list(index_params.except(:limit, :page, :sort_by, :sort_order))
    profiles = sort(profiles, columns: SortConstants::Columns::AI_PROFILE)
    pagy, records = pagy(:offset, profiles, limit: index_params[:limit])
    serialized = Ai::ProfileSerializer.collection_pagy(records, pagy)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::PROFILES_FETCHED),
      data: serialized[:data],
      meta: serialized[:meta].merge(config: Ai::ProfileService.config)
    )
  end

  # GET /v1/admin/ai/profiles/config
  def read_config
    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::CONFIG_FETCHED),
      data: Ai::ProfileService.config
    )
  end

  # POST /v1/admin/ai/profiles/sync_prices
  def update_sync_prices
    synced_count = Ai::ProfileService.sync_prices!

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::PRICES_SYNCED),
      data: Ai::ProfileService.config,
      meta: { synced_count: synced_count }
    )
  end

  # GET /v1/admin/ai/profiles/:id
  def show
    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::PROFILE_FETCHED),
      data: Ai::ProfileSerializer.record(@profile),
      meta: { config: Ai::ProfileService.config }
    )
  end

  # POST /v1/admin/ai/profiles
  def create
    profile = Ai::ProfileService.create!(profile_params)

    render_json_response(
      status_code: 201,
      message: ai_message(MessageService::Ai::PROFILE_CREATED),
      data: Ai::ProfileSerializer.record(profile)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_json_response(
      status_code: 422,
      message: ai_message(MessageService::Ai::PROFILE_CREATE_FAILED),
      error: error.record.errors.full_messages.to_sentence
    )
  end

  # PATCH/PUT /v1/admin/ai/profiles/:id
  def update
    profile = Ai::ProfileService.update!(@profile, profile_params)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::PROFILE_UPDATED),
      data: Ai::ProfileSerializer.record(profile)
    )
  rescue ActiveRecord::RecordInvalid => error
    render_json_response(
      status_code: 422,
      message: ai_message(MessageService::Ai::PROFILE_UPDATE_FAILED),
      error: error.record.errors.full_messages.to_sentence
    )
  end

  # DELETE /v1/admin/ai/profiles/:id
  def destroy
    Ai::ProfileService.destroy!(@profile)

    render_json_response(
      status_code: 200,
      message: ai_message(MessageService::Ai::PROFILE_DELETED)
    )
  rescue Ai::ProfileService::Error, ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError => error
    render_json_response(
      status_code: 422,
      message: ai_message(MessageService::Ai::PROFILE_DELETE_FAILED),
      error: error.message
    )
  end

  private

  def index_params
    params.permit(:provider, :model, :status, :enabled, :search, :sort_by, :sort_order, :limit, :page)
  end

  def set_profile
    @profile = Ai::ProfileService.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: ai_message(MessageService::Ai::NOT_FOUND),
      error: ai_message(MessageService::Ai::NOT_FOUND)
    )
  end

  def profile_params
    params.require(:profile).permit(
      :key,
      :provider,
      :name,
      :enabled,
      :model,
      :input_cost_per_million,
      :cached_cost_per_million,
      :output_cost_per_million,
      :temperature,
      :max_output_tokens,
      :context_max_tokens,
      :history_max_messages,
      :timeout_seconds,
      :system_prompt,
      settings: [ :top_p, :presence_penalty, :frequency_penalty, stop_sequences: [] ]
    )
  end

  def ai_message(key, **options)
    MessageService::Ai.t(key, **options)
  end
end
