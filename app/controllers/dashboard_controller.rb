class DashboardController < ApplicationController
  def index
    @dashboard = DashboardQuery.new.call
  end
end
