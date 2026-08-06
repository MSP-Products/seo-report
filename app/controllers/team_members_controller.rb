class TeamMembersController < ApplicationController
  before_action(only: [ :index ]) { require_permission!(:users_view) }

  def index
    @team_members = AdminUser.kept.includes(:role).order(:created_at)
  end
end
