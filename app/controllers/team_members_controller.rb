class TeamMembersController < ApplicationController
  before_action(only: [ :index ]) { require_permission!(:users_view) }
  before_action(only: [ :new, :create ]) { require_permission!(:users_invite) }
  before_action(only: [ :edit, :update ]) { require_permission!(:users_edit) }
  before_action(only: [ :destroy, :restore ]) { require_permission!(:users_remove) }

  def index
    @status = params[:status].presence_in(%w[ active removed all ]) || "active"
    scoped = case @status
    when "removed" then AdminUser.discarded
    when "all" then AdminUser.all
    else AdminUser.kept
    end
    @team_members = scoped.includes(:role).order(:created_at)
    @status_counts = { "active" => AdminUser.kept.count, "removed" => AdminUser.discarded.count, "all" => AdminUser.count }
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

  # Soft for a kept member (discard) and permanent only for an already-removed
  # one (destroy!) — the same button can't skip the reversible step, mirroring
  # ClientsController#destroy.
  def destroy
    admin_user = AdminUser.find(params[:id])
    if admin_user.discarded?
      admin_user.destroy!
      redirect_to team_members_path(status: "removed"), notice: "#{admin_user.display_name} permanently deleted."
    elsif admin_user.discard
      redirect_to team_members_path, notice: "#{admin_user.display_name} removed."
    else
      redirect_to team_members_path, alert: admin_user.errors.full_messages.to_sentence
    end
  end

  def restore
    admin_user = AdminUser.find(params[:id])
    admin_user.undiscard
    redirect_to team_members_path(status: "removed"), notice: "#{admin_user.display_name} restored."
  end
end
