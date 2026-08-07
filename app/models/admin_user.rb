# frozen_string_literal: true

class AdminUser < ApplicationRecord
  include Discard::Model
  has_secure_password

  # Transient — never a DB column. Set once by TeamMemberInviter/
  # TeamMemberResender so the one-time credentials screen can render it;
  # never persisted, never logged.
  attr_accessor :generated_password

  # Associations
  belongs_to :role

  has_many :admin_user_permissions, dependent: :destroy
  has_many :permissions, through: :admin_user_permissions
  has_many :admin_user_client_assignments, dependent: :destroy
  has_many :assigned_clients, through: :admin_user_client_assignments, source: :client

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validate :block_super_admin_role_change, on: :update, if: :role_id_changed?

  # Callbacks
  before_validation :downcase_email
  before_discard :block_if_last_super_admin!

  # Legacy compatibility only — ClientsController's and ConnectionsController's
  # require_editor! still call #admin? unchanged. Must keep returning exactly
  # what the old enum-backed admin?/support? returned for every migrated
  # account (admin/Super Admin & Admin -> admin? true; support/Account
  # Manager -> support? true). Deliberately role-only, not permission-aware:
  # a future Account Manager granted extra overrides still won't pass
  # require_editor!, since changing that gate's behavior is out of scope here.
  def admin?
    role.key.in?([ Role::SUPER_ADMIN, Role::ADMIN ])
  end

  def support?
    role.key == Role::ACCOUNT_MANAGER
  end

  def can?(permission_key)
    effective_permission_keys.include?(permission_key.to_s)
  end

  def invited?
    last_active_at.nil?
  end

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end

  # Which roles this admin_user may assign to someone else (self included) —
  # only a Super Admin may hand out the Super Admin role. Used by the invite
  # and edit forms to keep the visible options honest; TeamMemberInviter and
  # TeamMemberUpdater enforce the same rule server-side regardless.
  def assignable_roles
    role.key == Role::SUPER_ADMIN ? Role.all : Role.where.not(key: Role::SUPER_ADMIN)
  end

  # Throttled write, not validated: an activity ping is not a business edit
  # worth firing validations/callbacks on for every request.
  def touch_last_active
    return if last_active_at.present? && last_active_at > 5.minutes.ago

    update_column(:last_active_at, Time.current)
  end

  private

  def effective_permission_keys
    @effective_permission_keys ||= begin
      keys = role.permissions.pluck(:key).to_set
      admin_user_permissions.each { |override| override.granted? ? keys.add(override.permission_key) : keys.delete(override.permission_key) }
      keys
    end
  end

  def downcase_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  # discard's #discard uses update_attribute internally, which skips
  # validations but runs callbacks — so this guard has to be a before_discard
  # callback, not a plain `validate`, or it would silently never fire.
  def block_if_last_super_admin!
    return unless last_super_admin?

    errors.add(:base, "Can't remove the last Super Admin.")
    throw :abort
  end

  def block_super_admin_role_change
    return unless role_id_was == Role.super_admin.id
    return if AdminUser.kept.where(role_id: role_id_was).where.not(id: id).exists?

    errors.add(:role_id, "can't be changed away from Super Admin — this is the last one.")
  end

  def last_super_admin?
    role_id == Role.super_admin.id && !AdminUser.kept.where(role_id: role_id).where.not(id: id).exists?
  end
end
