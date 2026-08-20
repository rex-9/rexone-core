# app/services/access_service.rb
class AccessService
  class << self
    def grant(user_id:, product_id:, expires_at: nil)
      product = Payment::Product.find(product_id)

      resolved_expires_at =
        expires_at ||
        (product.recurring? ? product.cycle_in_duration.from_now : nil)

      # create_or_find_by! uses the unique database index to safely handle
      # two workers attempting to create the same access simultaneously.
      access = Access.create_or_find_by!(
        user_id: user_id,
        product_id: product_id
      ) do |record|
        record.status = AccessConstants::AccessStatus::ACTIVE
        record.granted_at = Time.current
        record.expires_at = resolved_expires_at
      end

      access.with_lock do
        # Preserve the original grant time when processing the same event again.
        access.granted_at ||= Time.current

        access.assign_attributes(
          status: AccessConstants::AccessStatus::ACTIVE,
          expires_at: resolved_expires_at,
          revoked_at: nil,
          expired_at: nil
        )

        access.save!
      end

      access
    end

    def revoke(user_id:, product_id:)
      access = Access.find_by(
        user_id: user_id,
        product_id: product_id
      )

      return unless access

      access.with_lock do
        access.revoke! if access.active?
      end
    end

    def has_access?(user_id:, product_id:)
      Access.exists?(
        user_id: user_id,
        product_id: product_id,
        status: AccessConstants::AccessStatus::ACTIVE
      ) && Access.where(
        user_id: user_id,
        product_id: product_id,
        status: AccessConstants::AccessStatus::ACTIVE
      ).where("expires_at IS NULL OR expires_at > ?", Time.current).exists?
    end

    def get_user_access(user_id)
      Access.includes(:product).where(user_id: user_id)
    end

    def get_active_access(user_id)
      Access.includes(:product)
           .where(user_id: user_id, status: AccessConstants::AccessStatus::ACTIVE)
           .where("expires_at IS NULL OR expires_at > ?", Time.current)
    end
  end
end
