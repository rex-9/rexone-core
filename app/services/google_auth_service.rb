require "net/http"
require "resolv"

class GoogleAuthService
  HttpResponse = Data.define(:body, :code)

  def self.fetch_user_info(token)
    return nil if token.blank?

    # 1. Try Google tokeninfo endpoint (for ID tokens)
    begin
      response = execute_get(
        AuthConstants::Google::TOKENINFO_URL,
        { id_token: token }
      )
      user_info = JSON.parse(response.body)
      return user_info if user_info["email"].present?
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.info "Google ID Token check failed (trying access_token next): #{e.http_code}"
    rescue StandardError => e
      Rails.logger.error "Google ID Token check error: #{e.message}"
    end

    # 2. Try Google userinfo endpoint (for access tokens)
    begin
      response = execute_get(
        AuthConstants::Google::USERINFO_URL,
        { access_token: token, alt: "json" }
      )
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse => e
      body = e.response&.body
      Rails.logger.error "Google Access Token Verification Failed (#{e.http_code}): #{body}"
      nil
    rescue StandardError => e
      Rails.logger.error "Google Auth Connection Error: #{e.class} - #{e.message}"
      nil
    end
  end

  def self.execute_get(url, params)
    RestClient::Request.execute(
      method: :get,
      url: url,
      headers: { params: params },
      timeout: AuthConstants::Google::TIMEOUT,
      open_timeout: AuthConstants::Google::TIMEOUT
    )
  rescue Errno::ENETUNREACH, Errno::EHOSTUNREACH, SocketError
    execute_ipv4_get(url, params)
  end

  def self.execute_ipv4_get(url, params)
    uri = URI.parse(url)
    uri.query = URI.encode_www_form(params)

    ipv4_address = Resolv::DNS.open do |dns|
      dns.timeouts = AuthConstants::Google::TIMEOUT
      dns.getresources(uri.host, Resolv::DNS::Resource::IN::A).first&.address&.to_s
    end
    raise Errno::ENETUNREACH, "No IPv4 A record found for #{uri.host}" if ipv4_address.blank?

    http = Net::HTTP.new(uri.host, uri.port)
    http.ipaddr = ipv4_address
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = AuthConstants::Google::TIMEOUT
    http.read_timeout = AuthConstants::Google::TIMEOUT

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise RestClient::ExceptionWithResponse.new(
        HttpResponse.new(body: response.body, code: response.code.to_i),
        response.code.to_i
      )
    end

    HttpResponse.new(body: response.body, code: response.code.to_i)
  end

  private_class_method :execute_get, :execute_ipv4_get
end
