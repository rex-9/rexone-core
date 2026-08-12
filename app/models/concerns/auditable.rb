# app/models/concerns/auditable.rb

module Auditable
  extend ActiveSupport::Concern

  included do
    belongs_to :creator,
               class_name: "User",
               foreign_key: :created_by_id,
               optional: true

    belongs_to :updater,
               class_name: "User",
               foreign_key: :updated_by_id,
               optional: true

    belongs_to :discarder,
               class_name: "User",
               foreign_key: :discarded_by_id,
               optional: true

    belongs_to :undiscarder,
               class_name: "User",
               foreign_key: :undiscarded_by_id,
               optional: true

    before_create :audit_create
    before_update :audit_update

    before_discard :audit_discard
    before_undiscard :audit_undiscard
  end

  private

  def auditor
    Current.auditor
  end

  def audit_create
    return unless auditor.present?

    self.created_by_id ||= auditor.id
    self.updated_by_id ||= auditor.id
  end

  def audit_update
    self.updated_by_id = auditor.id if auditor.present?
  end

  def audit_discard
    return unless auditor.present?

    self.discarded_by_id = auditor.id
    self.discarded_at = Time.current
  end

  def audit_undiscard
    return unless auditor.present?

    self.undiscarded_by_id = auditor.id
    self.undiscarded_at = Time.current
  end
end
