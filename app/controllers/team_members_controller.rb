class TeamMembersController < ApplicationController
  before_action(only: [ :index ]) { require_permission!(:users_view) }
  before_action(only: [ :new, :create ]) { require_permission!(:users_invite) }

  def index
    @team_members = AdminUser.kept.includes(:role).order(:created_at)
  end

  def new
    @admin_user = AdminUser.new
  end

  def create
    attrs = params.require(:admin_user).permit(:email, :first_name, :last_name, :role_id)
    @admin_user = TeamMemberInviter.new(attrs: attrs, actor: current_admin_user).call

    if @admin_user.persisted?
      render :created
    else
      render :new, status: :unprocessable_entity
    end
  end
end
