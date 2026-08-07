class TeamMembersController < ApplicationController
  before_action(only: [ :index ]) { require_permission!(:users_view) }
  before_action(only: [ :new, :create ]) { require_permission!(:users_invite) }
  before_action(only: [ :edit, :update ]) { require_permission!(:users_edit) }
  before_action(only: [ :destroy ]) { require_permission!(:users_remove) }

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

  def edit
    @admin_user = AdminUser.kept.find(params[:id])
  end

  def update
    admin_user = AdminUser.kept.find(params[:id])
    attrs = params.require(:admin_user).permit(:email, :first_name, :last_name, :role_id)
    @admin_user = TeamMemberUpdater.new(admin_user: admin_user, attrs: attrs, actor: current_admin_user).call

    if @admin_user.errors.empty?
      redirect_to team_members_path, notice: "#{@admin_user.display_name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    admin_user = AdminUser.kept.find(params[:id])
    admin_user.discard

    if admin_user.errors.empty?
      redirect_to team_members_path, notice: "#{admin_user.display_name} removed."
    else
      redirect_to team_members_path, alert: admin_user.errors.full_messages.to_sentence
    end
  end
end
