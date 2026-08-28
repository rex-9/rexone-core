# app/controllers/v1/admin/feedbacks_controller.rb

class V1::Admin::FeedbacksController < V1::ApplicationController
  # GET /v1/admin/feedbacks
  def index
    feedbacks = Feedback.recent
                        .by_status(params[:status])
                        .by_category(params[:category])
                        .by_priority(params[:priority])
                        .by_platform(params[:platform])
                        .by_user(params[:user_id])

    pagy, records = pagy(:offset, feedbacks, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: feedback_message(MessageService::Feedback::FETCHED),
      data: FeedbackSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/feedbacks/:id
  def show
    feedback = Feedback.find(params[:id])

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

  # PUT/PATCH /v1/admin/feedbacks/:id
  def update
    feedback = Feedback.find(params[:id])

    if feedback.update(admin_feedback_params)
      render_json_response(
        status_code: 200,
        message: feedback_message(MessageService::Feedback::UPDATED),
        data: FeedbackSerializer.new(feedback).serializable_hash[:data]
      )
    else
      render_json_response(
        status_code: 422,
        message: feedback_message(MessageService::Feedback::UPDATED),
        error: feedback.errors.full_messages.join(", ")
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: feedback_message(MessageService::Feedback::NOT_FOUND),
      error: feedback_message(MessageService::Feedback::NOT_FOUND)
    )
  end

  # DELETE /v1/admin/feedbacks/:id
  def destroy
    feedback = Feedback.find(params[:id])
    feedback.discard

    render_json_response(
      status_code: 200,
      message: feedback_message(MessageService::Feedback::DESTROYED)
    )
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: feedback_message(MessageService::Feedback::NOT_FOUND),
      error: feedback_message(MessageService::Feedback::NOT_FOUND)
    )
  end

  private

  def admin_feedback_params
    params.require(:feedback).permit(
      :status,
      :category,
      :priority,
      :admin_notes
    )
  end

  def feedback_message(key, **options)
    MessageService::Feedback.t(key, **options)
  end
end
