class DashboardController < ApplicationController
  def index
    @dashboard = DashboardPresenter.new
  end
end
