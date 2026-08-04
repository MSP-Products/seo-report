class ReportGenerationsController < ApplicationController
  before_action :require_editor!

  def create
    ReportGenerationScheduler.new(client_id: params[:client_id]).call
    redirect_to request.referer || dashboard_path, notice: "Report generation queued."
  end
end
