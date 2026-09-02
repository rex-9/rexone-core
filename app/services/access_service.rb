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

    def list_for_admin(status: nil, product_id: nil, user_id: nil, search: nil)
      scope = Access.includes(:user, :product)
      scope = scope.where(user_id: user_id) if user_id.present?
      scope = scope.where(product_id: product_id) if product_id.present?

      case status
      when AccessConstants::AccessStatus::ACTIVE
        scope = scope.where(status: AccessConstants::AccessStatus::ACTIVE)
                     .where("expires_at IS NULL OR expires_at > ?", Time.current)
      when AccessConstants::AccessStatus::EXPIRED
        scope = scope.where("status = ? OR (expires_at IS NOT NULL AND expires_at <= ?)",
                            AccessConstants::AccessStatus::EXPIRED, Time.current)
      when AccessConstants::AccessStatus::REVOKED
        scope = scope.where(status: AccessConstants::AccessStatus::REVOKED)
      when "expiring_soon"
        scope = scope.where(status: AccessConstants::AccessStatus::ACTIVE)
                     .where("expires_at IS NOT NULL AND expires_at > ? AND expires_at <= ?",
                            Time.current, 7.days.from_now)
      end

      if search.present?
        sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(search.strip)}%"
        scope = scope.joins(:user).where("users.email ILIKE :q OR users.name ILIKE :q OR users.username ILIKE :q", q: sanitized)
      end

      scope
    end

    def extend_access(access:, days: nil, expires_at: nil)
      resolved_expires_at = if expires_at.present?
        expires_at
      elsif days.present?
        base_time = [ access.expires_at || Time.current, Time.current ].max
        base_time + days.to_i.days
      else
        access.expires_at
      end

      access.with_lock do
        access.update!(
          expires_at: resolved_expires_at,
          status: AccessConstants::AccessStatus::ACTIVE,
          revoked_at: nil,
          expired_at: nil
        )
      end

      access
    end
  end
end
