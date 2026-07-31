module Messages
  # ===== AUTH =====
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

  # ===== PAYMENT =====
  PAYMENT_SUCCESS_TITLE = "Payment Successful! 🎉"
  PAYMENT_SUCCESS_BODY = ->(product_name:, amount:) { "Your payment of #{amount} for #{product_name} was successful." }

  SUBSCRIPTION_CREATED_TITLE =  ->(product_name:) { "Welcome to #{product_name} 🎉" }
  SUBSCRIPTION_CREATED_BODY = "Your subscription has been activated. You now have full access."

  SUBSCRIPTION_CANCELED_TITLE = "Subscription Canceled"
  SUBSCRIPTION_CANCELED_BODY = ->(product_name:, active_until:) do
    msg = "Your subscription to #{product_name} has been canceled."
    msg += " You have access until #{active_until}." if active_until
    msg
  end

  SUBSCRIPTION_RESUMED_TITLE = "Subscription Resumed ✅"
  SUBSCRIPTION_RESUMED_BODY = ->(product_name:) { "Your subscription to #{product_name} has been resumed." }

  PAYMENT_FAILED_TITLE = "Payment Failed ⚠️"
  PAYMENT_FAILED_BODY = ->(product_name:, amount:) { "We couldn't process your payment of #{amount} for #{product_name}." }

  # ===== PUSH =====
  PUSH_WELCOME_TITLE = "Welcome aboard! 🎉"
  PUSH_WELCOME_BODY = ->(name:) { "Hey #{name}, thanks for joining! We're excited to have you." }

  PUSH_SIGN_IN_ALERT_TITLE = "New Sign In"
  PUSH_SIGN_IN_ALERT_BODY = ->(name:) { "Hi #{name}, we noticed a new sign-in to your account." }

  # ===== EMAIL TEMPLATES (OneSignal) =====
  EMAIL_TEMPLATE_SUBSCRIPTION_CONFIRMATION = "payment_subscription_confirmation"
  EMAIL_TEMPLATE_PURCHASE_CONFIRMATION = "payment_purchase_confirmation"
  EMAIL_TEMPLATE_SUBSCRIPTION_CANCELED = "payment_subscription_canceled"
  EMAIL_TEMPLATE_SUBSCRIPTION_RESUMED = "payment_subscription_resumed"
  EMAIL_TEMPLATE_PAYMENT_FAILED = "payment_failed"
  EMAIL_TEMPLATE_CONFIRMATION = "email_confirmation"
  EMAIL_TEMPLATE_PASSWORD_RESET = "password_reset"
end
