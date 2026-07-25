# app/services/access_service.rb
class AccessService
  class << self
    def grant(user_id:, product_id:, expires_at: nil)
      product = Payment::Product.find(product_id) if product_id.present?

      # Deactivate old grants for this product
      Access.where(user_id: user_id, product_id: product_id).update_all(status: "revoked")

      grant = Access.create!(
        user_id: user_id,
        product_id: product_id,
        status: "active",
        granted_at: Time.current,
        expires_at: expires_at || (product&.recurring? ? product.cycle_in_duration.from_now : nil),
      )

      # Send notification
      # AccessNotificationService.send_granted(user_id, product_id)

      grant
    end

    def revoke(user_id:, product_id:)
      accesses = Access.where(user_id: user_id, product_id: product_id, status: "active")
      accesses.each { |a| a.revoke! }
      accesses.count
    end

    def has_access?(user_id:, product_id:)
      Access.exists?(
        user_id: user_id,
        product_id: product_id,
        status: "active"
      ) && Access.where(
        user_id: user_id,
        product_id: product_id,
        status: "active"
      ).where("expires_at IS NULL OR expires_at > ?", Time.current).exists?
    end

    def get_user_access(user_id)
      Access.includes(:product).where(user_id: user_id)
    end

    def get_active_access(user_id)
      Access.includes(:product)
           .where(user_id: user_id, status: "active")
           .where("expires_at IS NULL OR expires_at > ?", Time.current)
    end
  end
end
