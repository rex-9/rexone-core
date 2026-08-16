require "ostruct"

guard :rspec,
      cmd: "RAILS_ENV=test bundle exec rspec",
      all_on_start: true,
      notification: false do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch(%r{^app/(models|services|jobs|channels)/(.+)\.rb$}) do |m|
    "spec/#{m[1]}/#{m[2]}_spec.rb"
  end
  watch(%r{^app/controllers/.+\.rb$}) { "spec/requests" }
  watch(%r{^spec/(rails_helper|spec_helper)\.rb$}) { "spec" }
  watch(%r{^spec/support/.+\.rb$}) { "spec" }
  watch("config/routes.rb") { "spec/requests" }
end
