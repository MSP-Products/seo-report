# Manual testing against real third-party APIs, one client at a time.
# Credentials come from ENV only — never hardcode a real key here, this file is committed.
namespace :reports do
  desc "Seed (or update) one real client's credentials from ENV, for testing adapters against live APIs"
  task seed_real_client: :environment do
    client = Client.find_or_create_by!(name: ENV.fetch("REAL_CLIENT_NAME", "Adams Dental Associates")) do |c|
      c.website_url = ENV["REAL_CLIENT_WEBSITE"]
      c.address = ENV["REAL_CLIENT_ADDRESS"]
      c.onboarding_status = "active"
      c.onboarded_at = Time.current
      c.ai_seo_enrolled = true
    end

    {
      "hubspot" => { credentials: { access_token: ENV["HUBSPOT_ACCESS_TOKEN"] }, external_id: ENV["HUBSPOT_COMPANY_ID"] },
      "ghl" => { credentials: { access_token: ENV["GHL_ACCESS_TOKEN"] }, external_id: ENV["GHL_LOCATION_ID"] },
      "yext" => { credentials: { api_key: ENV["YEXT_API_KEY"] }, external_id: ENV["YEXT_ENTITY_ID"] },
      "semrush" => { credentials: { api_key: ENV["SEMRUSH_API_KEY"] }, external_id: ENV["SEMRUSH_PROJECT_ID"] }
    }.each do |service, creds|
      if creds[:external_id].blank? || creds[:credentials].values.all?(&:blank?)
        puts "  #{service}: skipped (no ENV credentials given)"
        next
      end

      link = client.client_service_links.find_or_initialize_by(service: service)
      link.update!(external_id: creds[:external_id], override_credentials: creds[:credentials].to_json)
      puts "  #{service}: linked to #{creds[:external_id]}"
    end

    puts "Seeded #{client.name} (#{client.id})"
  end

  desc "Run ReportGenerator against a real, seeded client and print the result (for live API verification)"
  task :generate_real, [ :client_name ] => :environment do |_, args|
    client_name = args[:client_name] || ENV.fetch("REAL_CLIENT_NAME", "Adams Dental Associates")
    client = Client.kept.find_by!(name: client_name)
    month = ENV["REPORT_MONTH"].present? ? Date.parse("#{ENV['REPORT_MONTH']}-01") : Date.current.beginning_of_month - 1.month

    report = ReportGenerator.new(client: client, month: month).call
    log = report.report_generation_logs.latest_first.first

    puts "Report: #{Rails.application.routes.url_helpers.public_report_url(report.access_token, host: ENV.fetch('APP_HOST', 'localhost:3000'))}"
    puts "Status: #{log.status}"
    puts "Warnings:\n#{log.error_log}" if log.error_log.present?
  rescue ActiveRecord::RecordNotFound
    puts "No client named #{client_name.inspect} — run reports:seed_real_client first."
  end
end
