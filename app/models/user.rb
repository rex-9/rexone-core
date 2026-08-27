# app/models/user.rb

class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher
  has_many :assets, -> { where("LOWER(resource_model) = 'user'") }, foreign_key: :resource_id, dependent: :nullify
  has_many :subscriptions, class_name: "Payment::Subscription", dependent: :destroy
  has_many :transactions, class_name: "Payment::Transaction", dependent: :destroy
  has_many :accesses, dependent: :destroy
  has_many :rooms, class_name: "Chat::Room", dependent: :destroy
  has_many :messages, through: :rooms, class_name: "Chat::Message"
  has_many :user_roles, class_name: "Iam::UserRole", dependent: :destroy
  has_many :roles, through: :user_roles, class_name: "Iam::Role"

  devise :database_authenticatable, :registerable, :validatable, :confirmable,
  :recoverable, :rememberable, :lockable, :trackable, :timeoutable,
  :jwt_authenticatable, jwt_revocation_strategy: self
  # Include default devise modules. Others available are:
  # :omniauthable

  before_create :generate_confirmation_code
  after_create :assign_default_user_role, if: -> { roles.empty? }

  self.primary_key = "id"

  validates :name, presence: true, length: { maximum: 50 }, format: { without: /[<>:;?]/ }
  validates :email, uniqueness: true, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, confirmation: true, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :password_confirmation, presence: true, if: -> { (new_record? || !password.nil?) }
  validates :username,
            presence: true,
            uniqueness: { case_sensitive: false },
            length: { in: 3..30 },
            format: {
              with: /\A[a-z0-9_]+\z/,
              message: :invalid_format
            }

  def generate_confirmation_code
    self.confirmation_code = SecureRandom.random_number(10**6).to_s.rjust(6, "0")
    self.confirmation_sent_at = Time.current
  end

  def confirm_code(code)
    if confirmation_code == code &&
      confirmation_sent_at.present? &&
      confirmation_sent_at > AppConfig::CONFIRM_CODE_WITHIN.ago
      confirm
    else
      errors.add(:confirmation_code, :invalid_or_expired)
      false
    end
  end

  def get_profile_pic_url
    # get 'upload' first and then 'google'
    profile_picture = assets
                      .where(type: AssetConstants::AssetType::AVATAR)
                      .order(Arel.sql("CASE WHEN source = 'upload' THEN 1 ELSE 2 END"), created_at: :desc)
                      .first
    profile_picture&.url
  end

  def stripe_customer
    return stripe_customer_id if stripe_customer_id.present?

    # Create Stripe customer if not exists
    customer = Stripe::Customer.create(email: email, metadata: { user_id: id })
    update(stripe_customer_id: customer.id)
    customer.id
  rescue Stripe::StripeError => e
    Rails.logger.error(
      "#{PaymentService::Stripe::STRIPE_LOG_PREFIX} " \
      "Failed to create customer: #{e.message}"
    )
    nil
  end

  # IAM
  def has_role?(role_name)
    roles.exists?(name: role_name.to_s)
  end

  def has_permission?(action, resource)
    roles.joins(:permissions).exists?(
      iam_permissions: {
        action: action.to_s,
        resource: resource.to_s
      }
    )
  end

  def can?(action, resource)
    # Super admin can do anything
    return true if super_admin?

    # Check specific permission
    has_permission?(action, resource)
  end

  def admin?
    roles.where(name: "admin").or(roles.where("name LIKE ?", "%\\_admin")).exists?
  end

  def super_admin?
    has_role?("super_admin")
  end

  def permissions
    # Get all permissions directly through roles
    Iam::Permission.joins(roles: :user_roles)
                   .where(iam_user_roles: { user_id: id })
                   .distinct
  end

  # Serializer helper
  def role_names
    roles.pluck(:name)
  end

  private

  def assign_default_user_role
    default_role = Iam::Role.find_by(name: "user")
    if default_role
      Iam::UserRole.find_or_create_by!(user: self, role: default_role)
    end
  end
end
