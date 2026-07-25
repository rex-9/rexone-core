# config/initializers/stripe.rb
require "stripe"

Stripe.api_key = ENV.fetch("STRIPE_SECRET_KEY")
Stripe.max_network_retries = 2
Stripe.log_level = "info" if Rails.env.development?
