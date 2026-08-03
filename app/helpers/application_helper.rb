module ApplicationHelper
  ADMIN_NAV_ICONS = { dashboard: :dashboard, clients: :building, connections: :link, report_log: :file_text }.freeze

  def admin_nav_icon(key)
    ADMIN_NAV_ICONS.fetch(key)
  end
end
