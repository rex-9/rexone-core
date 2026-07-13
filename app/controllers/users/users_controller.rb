class Users::UsersController < ApplicationController
  before_action :authenticate_user!, except: [ :peek_user ]  # Skip authentication for this action

  # GET /users/current
  def get_current_user
    if current_user
      render_json_response(
        status_code: 200,
        message: "Current user fetched successfully.",
        data: { user: UserSerializer.new(current_user).serializable_hash[:data][:attributes] }
      )
    else
      render_json_response(
        status_code: 401,
        message: "User not authenticated.",
        error: "No current user found."
      )
    end
  end

  # GET /users/peek?email=user@example.com
  # or POST /users/peek
  def peek_user
    email = params[:email]

    if email.blank?
      render_json_response(
        status_code: 400,
        message: "Email parameter is required.",
        error: "Missing email address."
      )
      return
    end

    user = User.find_by(email: email.to_s.downcase.strip)

    render_json_response(
      status_code: 200,
      message: "User existence checked successfully.",
      data: {
        user_exists: user.present?,
        confirmed: user&.confirmed? || false,
      }
    )
  end
end
