# frozen_string_literal: true

class Clients::HubspotSearchesController < ApplicationController
  before_action :require_editor!

  def index
    @query = params[:q]
    @matches = @query.present? ? HubspotCompanySearcher.new(@query).call : []
  end
end
