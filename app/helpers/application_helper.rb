module ApplicationHelper
  ADMIN_NAV_ICONS = {
    dashboard: :dashboard, clients: :building, connections: :link,
    team: :users, send_history: :file_text
  }.freeze

  # Onboarding, generation, and send-status labels all share one badge palette
  # (dashboard/clients static data uses the same words for each).
  BADGE_STYLES = {
    "Active" => "bg-emerald-100 text-emerald-700",
    "Ready" => "bg-emerald-100 text-emerald-700",
    "Sent" => "bg-emerald-100 text-emerald-700",
    "Generated" => "bg-emerald-100 text-emerald-700",
    "Pending" => "bg-amber-100 text-amber-700",
    "Generating" => "bg-cyan-100 text-cyan-700",
    "Failed" => "bg-red-100 text-red-700",
    "Offboarded" => "bg-slate-100 text-slate-600",
    "Not Sent" => "bg-slate-100 text-slate-600",
    "Not yet generated" => "bg-slate-100 text-slate-600"
  }.freeze

  def admin_nav_icon(key)
    ADMIN_NAV_ICONS.fetch(key)
  end

  def badge_class(status)
    BADGE_STYLES.fetch(status, "bg-slate-100 text-slate-600")
  end

  def send_status_class(status)
    "badge #{badge_class(status)}"
  end
end
