module Messages
  SIGNED_IN_SUCCESSFULLY = "Signed in successfully."
  FAILED_TO_SIGN_IN = "Failed to sign in."
  SIGNED_OUT_SUCCESSFULLY = "Signed out successfully."
  FAILED_TO_SIGN_OUT = "Failed to sign out."
  SIGNED_UP_SUCCESSFULLY = "Signed up successfully."
  FAILED_TO_SIGN_UP = "Failed to sign up."
  GOOGLE_AUTHENTICATION_FAILED = "Google authentication failed."
  USER_ALREADY_REGISTERED_WITH_GOOGLE = ->(email) { "#{email} is already registered with Google. Please sign in using Google." }
  USER_ALREADY_REGISTERED_WITH_EMAIL = ->(email) { "#{email} is already registered. Please log in with your Password." }
  VERIFICATION_EMAIL_SENT = ->(email) { "Verification email sent to #{email} successfully." }
  FAILED_TO_SEND_VERIFICATION_EMAIL = ->(email) { "Failed to send verification email to #{email}. Please try again." }
  EMAIL_ALREADY_CONFIRMED = "Email already confirmed. Please sign in."
  EMAIL_FAILED_TO_CONFIRM = "Email Confirmation Failed."
  EMAIL_CONFIRMED_SUCCESSFULLY = "Email Confirmed Successfully."
  USER_NOT_FOUND = "User not found."
  EMAIL_NOT_FOUND = "Email not found."
  ACTIVE_SESSION_NOT_FOUND = "Active session not found."
  PASSWORD_RESET_INSTRUCTIONS_SENT = ->(email) { "Password reset instructions have been sent to your email - #{email}." }
  PASSWORD_RESET_SUCCESSFULLY = "Password has been reset successfully. Sign in with your new password."
  FAILED_TO_RESET_PASSWORD = "Failed to reset password."
  INVALID_LOGIN_CREDENTIALS = "Invalid login credentials."
  INVALID_AUTHENTICATION_TOKEN = "Invalid authentication token"
  ACCOUNT_CREATED_AND_SIGNED_IN_SUCCESSFULLY = "Account created and signed in successfully."
  FAILED_TO_SAVE_GOOGLE_PHOTO = "Failed to save Google Profile Picture."
  ACCOUNT_DELETED_SUCCESSFULLY = "Account deleted successfully."
end
