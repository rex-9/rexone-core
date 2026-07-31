# app/channels/application_cable/connection.rb

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = authenticate!
    end

    private

    def authenticate!
      token = request.params[:token]
      reject_unauthorized_connection unless token.present?

      payload = Warden::JWTAuth::TokenDecoder.new.call(token)

      User.find(payload["sub"])
    rescue JWT::DecodeError,
           JWT::ExpiredSignature,
           ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end
  end
end
