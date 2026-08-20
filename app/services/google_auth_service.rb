class GoogleAuthService
  def self.fetch_user_info(token)
    return nil if token.blank?

    begin
      response = RestClient.get("https://www.googleapis.com/oauth2/v3/tokeninfo", { params: { id_token: token } })
      user_info = JSON.parse(response.body)
      return user_info if user_info["email"].present?
    rescue RestClient::ExceptionWithResponse
      # Not an ID token or token is invalid. Try Google userinfo endpoint as access token.
    end

    response = RestClient.get("https://www.googleapis.com/oauth2/v1/userinfo", { params: { access_token: token, alt: "json" } })
    JSON.parse(response.body)
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error(
      "[Auth] Google authentication failed: " \
      "#{e.response&.body || e.response}"
    )
    nil
  end
end
