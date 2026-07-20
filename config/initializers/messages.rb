module Messages
  SIGNED_IN_SUCCESSFULLY = "Signed in successfully."
  FAILED_TO_SIGN_IN = "Failed to sign in."
  SIGNED_OUT_SUCCESSFULLY = "Signed out successfully."
  FAILED_TO_SIGN_OUT = "Failed to sign out."
  SIGNED_UP_SUCCESSFULLY = "Signed up successfully."
  FAILED_TO_SIGN_UP = "Failed to sign up."
  GOOGLE_AUTHENTICATION_FAILED = "Google authentication failed."
  USER_ALREADY_SIGNEDUP_WITH_GOOGLE = ->(email) { "#{email} is already signed up with Google. Please sign in using Google." }
  USER_ALREADY_SIGNEDUP_WITH_EMAIL = ->(email) { "#{email} is already signed up. Please log in with your Passcode." }
  CONFIRMATION_EMAIL_SENT = ->(email) { "Verification email sent to #{email} successfully." }
  EMAIL_ALREADY_CONFIRMED = "Email already confirmed. Please sign in."
  EMAIL_FAILED_TO_CONFIRM = "Email Confirmation Failed."
  EMAIL_CONFIRMED_SUCCESSFULLY = "Email Confirmed Successfully."
  USER_NOT_FOUND = "User not found."
  EMAIL_NOT_FOUND = "Email not found."
  ACTIVE_SESSION_NOT_FOUND = "Active session not found."
  PASSWORD_RESET_INSTRUCTIONS_SENT = ->(email) { "Passcode reset instructions have been sent to your #{email}." }
  PASSWORD_RESET_SUCCESSFULLY = "Passcode has been reset successfully. Sign in with your new passcode."
  FAILED_TO_RESET_PASSWORD = "Failed to reset passcode."
  INVALID_SIGNIN_CREDENTIALS = "Invalid sign in credentials."
  INVALID_AUTHENTICATION_TOKEN = "Invalid authentication token"
  ACCOUNT_CREATED_AND_SIGNED_IN_SUCCESSFULLY = "Account created and signed in successfully."
  FAILED_TO_SAVE_GOOGLE_PHOTO = "Failed to save Google Profile Picture."
  ACCOUNT_DELETED_SUCCESSFULLY = "Account deleted successfully."

  PASSWORD_TOO_MANY_ATTEMPTS = "Too many incorrect passcode attempts."

  # ===== PUSH NOTIFICATION MESSAGES =====
  PUSH_WELCOME_TITLE = "Welcome aboard! 🎉"
  PUSH_WELCOME_BODY = ->(name:) { "Hey #{name}, thanks for joining! We're excited to have you." }

  PUSH_SIGN_IN_ALERT_TITLE = "New Sign In"
  PUSH_SIGN_IN_ALERT_BODY = ->(name:) { "Hi #{name}, we noticed a new sign-in to your account." }

  # ===== EMAIL MESSAGES =====
  EMAIL_CONFIRMATION_SUBJECT = "Verify your email address"
  EMAIL_CONFIRMATION_BODY = ->(code:, email:) {
    "Your verification code is: #{code}\n\n" \
    "Enter this code in the app to verify your email.\n\n" \
    "If you didn't request this, please ignore this email."
  }

  EMAIL_PASSWORD_RESET_SUBJECT = "Reset your password"
  EMAIL_PASSWORD_RESET_BODY = ->(token:) {
    "Click here to reset your password: " \
    "#{AppConfig::CLIENT_BASE_URL}/password/reset?reset_password_token=#{token}\n\n" \
    "This link will expire in 6 hours."
  }
end
