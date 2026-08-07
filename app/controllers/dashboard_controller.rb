class DashboardController < ApplicationController
  before_action { require_permission!(:dashboard_view) }

  def index
    @dashboard = DashboardPresenter.new
  end
end
