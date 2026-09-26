# app/controllers/v1/client_user_versions_controller.rb

class V1::Client::UserVersionsController < V1::ApplicationController
  # POST /v1/client/versions/user-version
  def create_install
    record = Client::UserVersionService.create(
      user: current_user,
      platform: platform_session,
      number: user_version_params[:version],
      version_code: user_version_params[:version_code]
    )
    created = record.previously_new_record?

    render_json_response(
      status_code: created ? 201 : 200,
      message: user_version_message(
        created ? MessageService::UserVersion::CREATED : MessageService::UserVersion::UPDATED
      ),
      data: Client::UserVersionSerializer.record(record)
    )
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
    error = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message

    render_json_response(
      status_code: 422,
      message: user_version_message(MessageService::UserVersion::CREATE_FAILED),
      error: error
    )
  end

  private

  def user_version_params
    params.require(:user_version).permit(:version, :version_code)
  end

  def user_version_message(key, **options)
    MessageService::UserVersion.t(key, **options)
  end
end
