# app/controllers/v1/feedbacks_controller.rb

class V1::FeedbacksController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :create ]
  skip_before_action :enforce_active_platform_session!, only: [ :create ]

  # POST /v1/feedbacks
  def create
    feedback = FeedbackService.create(
      feedback_params,
      user: current_user,
      platform: platform_session
    )

    render_json_response(
      status_code: 201,
      message: feedback_message(MessageService::Feedback::CREATED),
      data: FeedbackSerializer.new(feedback).serializable_hash[:data]
    )
  rescue ActiveRecord::RecordInvalid => e
    render_json_response(
      status_code: 422,
      message: feedback_message(MessageService::Feedback::CREATED),
      error: e.record.errors.full_messages.join(", ")
    )
  end

  # GET /v1/feedbacks
  def index
    feedbacks = current_user.feedbacks.recent
    pagy, records = pagy(:offset, feedbacks, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: feedback_message(MessageService::Feedback::FETCHED),
      data: FeedbackSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/feedbacks/:id
  def show
    feedback = current_user.feedbacks.find(params[:id])

    render_json_response(
      status_code: 200,
      message: feedback_message(MessageService::Feedback::FETCHED),
      data: FeedbackSerializer.new(feedback).serializable_hash[:data]
    )
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: feedback_message(MessageService::Feedback::NOT_FOUND),
      error: feedback_message(MessageService::Feedback::NOT_FOUND)
    )
  end

  private

  def feedback_params
    params.require(:feedback).permit(
      :content,
      :rating,
      :category,
      :priority,
      :app_version,
      :os,
      :device,
      :browser,
      :page,
      metadata: {}
    )
  end

  def feedback_message(key, **options)
    MessageService::Feedback.t(key, **options)
  end
end
