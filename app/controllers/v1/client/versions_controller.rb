# app/controllers/v1/versions_controller.rb

class V1::Client::VersionsController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :read_current ]
  skip_before_action :enforce_active_platform_session!, only: [ :read_current ]

  # GET /v1/client/versions/current
  def read_current
    result = Client::VersionService.check(
      version: current_params[:version],
      platform: platform_session,
      build_number: current_params[:build_number]
    )

    render_json_response(
      status_code: 200,
      message: version_message(MessageService::Version::CURRENT_FETCHED),
      data: { version: check_payload(result) }
    )
  end

  private

  def current_params
    params.permit(:version, :build_number)
  end

  def check_payload(result)
    extras = {
      update_required: result.update_required,
      must_update: result.must_update,
      skip_premium: result.skip_premium,
      store_url: result.store_url
    }

    if result.latest
      Client::VersionSerializer.new(result.latest, params: extras)
        .serializable_hash[:data][:attributes]
    else
      Client::VersionService::EMPTY_CATALOG.merge(extras)
    end
  end

  def version_message(key, **options)
    MessageService::Version.t(key, **options)
  end
end
