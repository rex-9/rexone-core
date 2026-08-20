FactoryBot.define do
  factory :log_client, class: "Log::Client" do
    message { "Unhandled exception: ReferenceError" }
    severity { "error" }
    platform { "web" }
    environment { "development" }
  end
end
