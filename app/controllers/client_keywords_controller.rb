class ClientKeywordsController < ApplicationController
  def index
    @client = Client.kept.find(params[:client_id])
    @client_keywords = @client.client_keywords
    @latest_report = @client.latest_generated_report
    @latest_report_presenter = ReportPresenter.new(@latest_report) if @latest_report
  end
end
