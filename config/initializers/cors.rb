# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "http://localhost:5173", # For dev
            "https://uat.auth-service.me", # For uat
            "http://uat.auth-service.me",
            "https://www.uat.auth-service.me",
            "http://www.uat.auth-service.me",
            "https://auth-service.me", # For prod
            "http://auth-service.me",
            "https://www.auth-service.me",
            "http://www.auth-service.me"

    resource "*",
      headers: :any,
      expose: [ "access-token", "expiry", "token-type", "Authorization" ],
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
