class ApplicationMailer < ActionMailer::Base
  default from: -> { AppConfig::FROM_EMAIL }
  layout "mailer"
end
