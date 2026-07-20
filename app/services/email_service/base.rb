# app/services/email_service/base.rb
module EmailService
  class Base
    def send_email(to:, subject:, body:, from: nil, reply_to: nil)
      raise NotImplementedError, "#{self.class} must implement #send_email"
    end

    def send_template(to:, template_id:, template_data:, from: nil)
      raise NotImplementedError, "#{self.class} must implement #send_template"
    end
  end
end
