FactoryBot.define do
  factory :feedback do
    content { "Great platform! Really loving the fast response times." }
    rating { 9 }
    category { FeedbackConstants::Category::GENERAL }
    priority { FeedbackConstants::Priority::NORMAL }
    status { FeedbackConstants::Status::NEW }
    platform { AuthConstants::Platform::WEB }
    page { "/home" }
    metadata { { viewport: "1920x1080" } }
  end
end
