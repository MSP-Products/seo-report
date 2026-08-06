# frozen_string_literal: true

class SessionsController < ApplicationController
  layout "auth"

  skip_before_action :authenticate_admin!, only: [ :new, :create ]

  def new; end

  def create
    admin_user = AdminUser.kept.find_by(email: session_params[:email]&.strip&.downcase)

    if admin_user&.authenticate(session_params[:password])
      session[:admin_user_id] = admin_user.id
      redirect_to root_path, notice: "Logged in successfully."
    else
      flash.now[:error] = "Incorrect email or password. Please try again."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_user_id)
    redirect_to login_path, notice: "Logged out successfully."
  end

  private

  def session_params
    params.permit(:email, :password)
  end
end
