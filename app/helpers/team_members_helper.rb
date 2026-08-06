module TeamMembersHelper
  # Friendly copy for a Permission#key — kept here, not on the model, since
  # this wording is a view concern and Permission itself has no display logic.
  PERMISSION_LABELS = {
    "clients_view" => "View clients", "clients_create" => "Add clients",
    "clients_edit" => "Edit clients", "clients_delete" => "Delete clients",
    "dashboard_view" => "View dashboard",
    "reports_view" => "View reports", "reports_generate" => "Generate reports",
    "report_logs_view" => "View report logs",
    "connections_view" => "View connections", "connections_edit" => "Edit API credentials",
    "users_view" => "View team members", "users_invite" => "Invite team members",
    "users_edit" => "Edit team members", "users_remove" => "Remove team members",
    "roles_manage" => "Manage roles", "user_permissions_manage" => "Manage individual permissions"
  }.freeze

  ROLE_BADGE_CLASSES = {
    "super_admin" => "bg-violet-100 text-violet-700",
    "admin" => "bg-teal-primary/10 text-teal-dark",
    "account_manager" => "bg-cyan-100 text-cyan-700"
  }.freeze

  def permission_label(permission_key)
    PERMISSION_LABELS.fetch(permission_key, permission_key.humanize)
  end

  def role_badge_class(role)
    ROLE_BADGE_CLASSES.fetch(role.key, "bg-slate-100 text-slate-600")
  end

  def member_initials(member)
    member.display_name.split.first(2).map { |word| word[0] }.join.upcase
  end

  def member_status_label(member, viewer)
    return "You" if member == viewer

    member.invited? ? "Invited" : "Active"
  end

  def member_last_active_label(member)
    return "—" if member.last_active_at.nil?
    return "Active now" if member.last_active_at > 5.minutes.ago

    "#{time_ago_in_words(member.last_active_at)} ago"
  end
end
