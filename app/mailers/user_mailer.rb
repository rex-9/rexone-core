class UserMailer < ApplicationMailer
  default from: "no-reply@example.com"

  def send_email_confirmation_mail(user)
    @user = user
    @url = @user.confirm_email_url
    mail(to: @user.email, subject: "Email Verification")
  end

  def send_password_reset_mail(user)
    @user = user
    @url = @user.reset_password_url
    mail(to: @user.email, subject: "Reset Passcode Instructions")
  end
end
