# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# db/seeds.rb
# Product.create!(
#   name: 'Meritbox 30-Day Program',
#   description: 'Complete 30-day transformation program with daily coaching',
#   price_unit_amount: 29700,
#   currency: 'usd',
#   stripe_price_id: 'price_program_30day',
#   cycle: nil,
#   active: true
# )

# Product.create!(
#   name: 'Meritbox Monthly Subscription',
#   description: 'Monthly access to all programs and coaching',
#   price_unit_amount: 4900,
#   currency: 'usd',
#   stripe_price_id: 'price_monthly_sub',
#   cycle: 'month',
#   active: true
# )

# Product.create!(
#   name: 'Meritbox Yearly Subscription',
#   description: 'Yearly access to all programs and coaching (save 20%)',
#   price_unit_amount: 47000,
#   currency: 'usd',
#   stripe_price_id: 'price_yearly_sub',
#   cycle: 'year',
#   active: true
# )
