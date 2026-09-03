class GoogleAuthService
  TIMEOUT = 10

  def self.fetch_user_info(token)
    return nil if token.blank?

    # 1. Try Google tokeninfo endpoint (for ID tokens)
    begin
      response = RestClient::Request.execute(
        method: :get,
        url: "https://www.googleapis.com/oauth2/v3/tokeninfo",
        headers: { params: { id_token: token } },
        timeout: TIMEOUT,
        open_timeout: TIMEOUT
      )
      user_info = JSON.parse(response.body)
      return user_info if user_info["email"].present?
    rescue RestClient::ExceptionWithResponse, JSON::ParserError
      # Not an ID token or invalid. Proceed to userinfo endpoint.
    rescue StandardError => e
      Rails.logger.warn("[Auth] Google tokeninfo lookup failed (#{e.class}): #{e.message}")
    end

    # 2. Try Google userinfo endpoint (for access tokens)
    begin
      response = RestClient::Request.execute(
        method: :get,
        url: "https://www.googleapis.com/oauth2/v1/userinfo",
        headers: { params: { access_token: token, alt: "json" } },
        timeout: TIMEOUT,
        open_timeout: TIMEOUT
      )
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.warn("[Auth] Google userinfo rejected token: #{e.response&.body || e.message}")
      nil
    rescue JSON::ParserError => e
      Rails.logger.error("[Auth] Google userinfo invalid JSON: #{e.message}")
      nil
    rescue StandardError => e
      Rails.logger.error("[Auth] Google authentication request failed (#{e.class}): #{e.message}")
      nil
    end
  end
end
