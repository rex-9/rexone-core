class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  devise :database_authenticatable, :registerable, :validatable, :confirmable,
  :recoverable, :rememberable, :lockable, :trackable, :timeoutable,
  :jwt_authenticatable, jwt_revocation_strategy: self
  # Include default devise modules. Others available are:
  # :omniauthable

  before_create :generate_confirmation_code

  self.primary_key = "id"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
  validates :password, presence: true, confirmation: true, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }
  validates :password_confirmation, presence: true, if: -> { (new_record? || !password.nil?) && provider != "google" }
  validates :name, length: { maximum: 50 }, format: { without: /[<>:;?]/ }, allow_blank: true
  validates :username, presence: true, uniqueness: { case_sensitive: false }, length: { in: 3..30 }, format: { with: /\A[a-z0-9_]+\z/, message: "can only contain lowercase letters, numbers, and underscores" }
  validate :photo_must_be_a_valid_url, if: -> { photo.present? }

  def generate_confirmation_code
    self.confirmation_code = SecureRandom.random_number(10**6).to_s.rjust(6, "0")
    self.confirmation_code_sent_at = Time.current
  end

  def confirm_with_code(code)
    if self.confirmation_code == code && self.confirmation_code_sent_at > 10.minutes.ago
      confirm
    else
      errors.add(:confirmation_code, "is invalid or has expired")
      false
    end
  end

  private

  def photo_must_be_a_valid_url
    uri = URI.parse(photo)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      errors.add(:photo, "must be a valid URL")
    end
  rescue URI::InvalidURIError
    errors.add(:photo, "must be a valid URL")
  end
end
