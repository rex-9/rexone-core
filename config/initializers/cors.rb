# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins "example.com"
#
#     resource "*",
#       headers: :any,
#       methods: [:get, :post, :put, :patch, :delete, :options, :head]
#   end
# end

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_list = []

    # Local development origins (ONLY allowed in development/test environments,
    # or if explicitly opted in via CORS_ALLOW_LOCALHOST=true to prevent cross-origin localhost attacks against prod/uat)
    if Rails.env.development? || Rails.env.test? || ENV["CORS_ALLOW_LOCALHOST"] == "true"
      origins_list << %r{\Ahttp://localhost(:\d+)?\z}
      origins_list << %r{\Ahttp://127\.0\.0\.1(:\d+)?\z}
    end

    # 1. Dynamic Product Domain (Supports ANY TLD: .com, .io, .ai, .app, .org, .me, etc.)
    # Set via PRODUCT_DOMAIN in environment (e.g., PRODUCT_DOMAIN=rexone.me or acme.com)
    if ENV["PRODUCT_DOMAIN"].present?
      p_domain = ENV["PRODUCT_DOMAIN"].strip
      origins_list += [
        "https://#{p_domain}", "http://#{p_domain}",
        "https://www.#{p_domain}", "http://www.#{p_domain}",
        "https://uat.#{p_domain}", "http://uat.#{p_domain}",
        "https://www.uat.#{p_domain}", "http://www.uat.#{p_domain}",
        "https://dev.#{p_domain}", "http://dev.#{p_domain}",
        "https://www.dev.#{p_domain}", "http://www.dev.#{p_domain}",
        %r{\Ahttps?://([a-zA-Z0-9-]+\.)*#{Regexp.escape(p_domain)}\z}
      ]
    end

    # 2. Live Demo Tier (Rex9 showcase deployment)
    # Explicit strings for http, https, www + wildcard for all demo subdomains
    origins_list += [
      "https://rexone.rex9.me", "http://rexone.rex9.me",
      "https://www.rexone.rex9.me", "http://www.rexone.rex9.me",
      "https://rex9.me", "http://rex9.me",
      "https://www.rex9.me", "http://www.rex9.me",
      %r{\Ahttps?://([a-zA-Z0-9-]+\.)*rex9\.me\z}
    ]

    # 3. Explicit Client Base URL (auto-adds http://, https://, and www. forms)
    if ENV["RAILS_CLIENT_BASE_URL"].present?
      client_url = ENV["RAILS_CLIENT_BASE_URL"].strip
      origins_list << client_url
      if client_url =~ %r{\Ahttps?://([^/:]+)(:\d+)?\z}
        host = $1
        port = $2 || ""
        origins_list << "https://#{host}#{port}"
        origins_list << "http://#{host}#{port}"
        unless host.start_with?("www.") || host == "localhost" || host == "127.0.0.1"
          origins_list << "https://www.#{host}#{port}"
          origins_list << "http://www.#{host}#{port}"
        end
      end
    end

    # 4. Comma-separated custom CORS origins
    if ENV["CORS_ORIGINS"].present?
      origins_list.concat(ENV["CORS_ORIGINS"].split(",").map(&:strip).reject(&:empty?))
    end

    # 5. Runtime dynamic resolver for live ENV changes (PRODUCT_DOMAIN and CORS_ORIGINS)
    origins_list << lambda { |source, _env|
      if ENV["PRODUCT_DOMAIN"].present?
        p_domain = ENV["PRODUCT_DOMAIN"].strip
        return true if source =~ %r{\Ahttps?://([a-zA-Z0-9-]+\.)*#{Regexp.escape(p_domain)}\z}
      end

      if ENV["CORS_ORIGINS"].present?
        return true if ENV["CORS_ORIGINS"].split(",").map(&:strip).include?(source)
      end

      false
    }

    origins(*origins_list)

    resource "*",
      headers: :any,
      expose: [ "access-token", "expiry", "token-type", "Authorization" ],
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
