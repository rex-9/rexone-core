# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :authenticate_admin

    attr_reader :current_user

    private

    def authenticate_admin
      authenticate_or_request_with_http_basic("Admin Area") do |username, password|
        user = User.find_by(username: username)

        next false unless user&.valid_password?(password)
        next false unless user.admin?

        @current_user = user
      end

      # http_basic_authenticate_or_request_with(
      #   name: AppConfig::RAILS_ADMIN_USERNAME,
      #   password: AppConfig::RAILS_ADMIN_PASSWORD
      # )
    end

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end
  end
end
