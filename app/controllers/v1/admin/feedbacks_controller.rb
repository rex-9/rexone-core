# app/controllers/v1/admin/feedbacks_controller.rb

class V1::Admin::FeedbacksController < V1::ApplicationController
  # GET /v1/admin/feedbacks
  def index
    filters = filter_params
    feedbacks = Feedback.by_status(filters[:status])
                        .by_category(filters[:category])
                        .by_priority(filters[:priority])
                        .by_platform(filters[:platform])
                        .by_user(filters[:user_id])

    feedbacks = sort(feedbacks, columns: SortConstants::Columns::FEEDBACK)
    pagy, records = pagy(feedbacks, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: feedback_message(MessageService::Feedback::FETCHED),
      data: FeedbackSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/feedbacks/:id
  def show
    feedback = Feedback.find(params.permit(:id)[:id])

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
    feedback = Feedback.find(params.permit(:id)[:id])

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
    feedback = Feedback.find(params.permit(:id)[:id])
    feedback.destroy!

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

  def filter_params
    params.permit(:status, :category, :priority, :platform, :user_id, :limit, :page)
  end

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
