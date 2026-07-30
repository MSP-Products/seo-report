module ApplicationHelper
  ADMIN_NAV_ICONS = { dashboard: :dashboard, clients: :building, connections: :link }.freeze

  def admin_nav_icon(key)
    ADMIN_NAV_ICONS.fetch(key)
  end
end
