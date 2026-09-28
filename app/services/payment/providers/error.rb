# frozen_string_literal: true

# app/services/payment/providers/error.rb
module Payment
  module Providers
    class Error < StandardError; end
    class ProviderError < Error; end
    class VerificationError < Error; end
    class SignatureVerificationError < Error; end
  end

  Error = Providers::Error unless defined?(Payment::Error)
end
