class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_admin!

  helper_method :current_admin_user

  private

  def current_admin_user
    @current_admin_user ||= AdminUser.find_by(id: session[:admin_user_id]) if session[:admin_user_id]
  end

  def authenticate_admin!
    unless current_admin_user
      redirect_to login_path, alert: "Please log in to continue."
    end
  end

  # Guards mutating actions — "support" admins can view everything but not
  # change it. Controllers opt in with `before_action :require_editor!, only: [...]`.
  def require_editor!
    unless current_admin_user&.admin?
      redirect_to request.referer || root_path, alert: "You don't have permission to do that."
    end
  end
end
