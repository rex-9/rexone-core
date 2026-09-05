# app/models/user.rb

class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher
  has_many :assets, as: :assetable, dependent: :nullify
  has_many :subscriptions, class_name: "Payment::Subscription", dependent: :destroy
  has_many :transactions, class_name: "Payment::Transaction", dependent: :destroy
  has_many :accesses, dependent: :destroy
  has_many :rooms, class_name: "Chat::Room", dependent: :destroy
  has_many :messages, through: :rooms, class_name: "Chat::Message"
  has_many :user_roles, class_name: "Iam::UserRole", dependent: :destroy
  has_many :roles, through: :user_roles, class_name: "Iam::Role"
  has_many :feedbacks, dependent: :nullify
  has_many :user_notifications, dependent: :destroy

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

  def send_confirmation_instructions
    generate_confirmation_code if confirmation_code.blank?
    save(validate: false) if changed?
    NotificationService::Center.confirmation_email(
      email: email,
      code: confirmation_code
    )
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

  def get_avatar_url
    assets.find_by(type: AssetConstants::AssetType::AVATAR)&.url
  end

  def stripe_customer
    result = PaymentService::Client.create_customer(user: self)
    result[:customer_id]
  end

  # IAM
  def has_role?(role_name)
    roles.exists?(name: role_name.to_s)
  end

  def admin_roles
    roles.where("iam_roles.name ILIKE '%admin%'")
  end

  def non_admin_roles
    roles.where.not("iam_roles.name ILIKE '%admin%'")
  end

  def admin?
    admin_roles.exists?
  end

  def super_admin?
    has_role?(IamConstants::Role::SUPER_ADMIN)
  end

  def has_permission?(action, resource, from_admin_role_only: false)
    scoped_roles = from_admin_role_only ? admin_roles : roles
    scoped_roles.joins(:permissions).exists?(
      iam_permissions: {
        action: action.to_s,
        resource: resource.to_s
      }
    )
  end

  def can?(action, resource, admin_scope: false)
    # Super admin can do anything
    return true if super_admin?

    has_permission?(action, resource, from_admin_role_only: admin_scope)
  end

  def permissions
    # Get all permissions directly through roles
    Iam::Permission.joins(roles: :user_roles)
                   .where(iam_user_roles: { user_id: id })
                   .distinct
  end

  def admin_permissions
    if super_admin?
      Iam::Permission.all
    else
      Iam::Permission.joins(roles: :user_roles)
                     .where(iam_user_roles: { user_id: id })
                     .where("iam_roles.name ILIKE '%admin%'")
                     .distinct
    end
  end

  def non_admin_permissions
    Iam::Permission.joins(roles: :user_roles)
                   .where(iam_user_roles: { user_id: id })
                   .where.not("iam_roles.name ILIKE '%admin%'")
                   .distinct
  end

  # Serializer helper
  def role_names
    roles.pluck(:name)
  end

  private

  def assign_default_user_role
    default_role = Iam::Role.find_by(name: IamConstants::Role::USER)
    if default_role
      Iam::UserRole.find_or_create_by!(user: self, role: default_role)
    end
  end
end
