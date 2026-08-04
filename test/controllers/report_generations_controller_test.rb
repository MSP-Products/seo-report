require "test_helper"

class ReportGenerationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "redirects to login when not authenticated" do
    post report_generations_path

    assert_redirected_to login_path
  end

  test "support role is blocked from queueing report generation" do
    sign_in_as(role: "support")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    assert_no_enqueued_jobs(only: GenerateMonthlyReportJob) do
      post report_generations_path, params: { client_id: client.id }
    end
    assert_redirected_to root_path
  end

  test "admin can queue a bulk run" do
    sign_in_as(role: "admin")
    Client.create!(name: "Some Practice", onboarding_status: "active")

    assert_enqueued_jobs 1, only: GenerateMonthlyReportJob do
      post report_generations_path
    end
    assert_redirected_to dashboard_path
  end

  test "admin can retry a single client" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    assert_enqueued_jobs 1, only: GenerateMonthlyReportJob do
      post report_generations_path, params: { client_id: client.id }
    end
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
