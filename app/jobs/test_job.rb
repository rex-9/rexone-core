# app/jobs/test_job.rb
class TestJob < ApplicationJob
  queue_as :default

  def perform(message = "Hello from worker!")
    Rails.logger.info("🎯 TestJob running: #{message}")
    sleep 1  # Simulate work
    Rails.logger.info("✅ TestJob finished")
  end
end

# Enqueue a test job
# TestJob.perform_later("Testing Pulse job tracking!")

# Enqueue multiple to see trends
# 5.times { TestJob.perform_later("Batch job ##{_1}") }

# app/jobs/send_welcome_email_job.rb
# class SendWelcomeEmailJob < ApplicationJob
#   queue_as :mailers

#   def perform(user_id)
#     user = User.find(user_id)
#     Rails.logger.info("📧 Sending welcome email to #{user.email}")

#     # Your email logic here
#     UserMailer.welcome(user).deliver_now

#     Rails.logger.info("✅ Welcome email sent to #{user.email}")
#   rescue => e
#     Rails.logger.error("❌ Failed to send welcome email: #{e.message}")
#     raise
#   end
# end

# Enqueue with
# SendWelcomeEmailJob.perform_later(user.id) # Don't pass large objects, just IDs or simple data types
