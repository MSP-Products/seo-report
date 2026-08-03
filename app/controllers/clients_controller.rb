class ClientsController < ApplicationController
  CLIENTS = [
    { id: 1, name: "Woodside Dental Care", address: "123 Oak Street, San Francisco, CA 94102", website: "woodsidedental.com",
      onboarding: "Active", last_report: "June 2026", generation: "Ready", send_status: "Sent", sent_date: "Jun 3, 2026" },
    { id: 2, name: "Bright Smiles Family Dentistry", address: "45 Maple Ave, Oakland, CA 94610", website: "brightsmilesfamily.com",
      onboarding: "Active", last_report: "June 2026", generation: "Failed", send_status: "Not Sent", sent_date: nil },
    { id: 3, name: "Metro Orthodontics", address: "900 Market St, San Francisco, CA 94103", website: "metroortho.com",
      onboarding: "Active", last_report: "June 2026", generation: "Generating", send_status: "Not Sent", sent_date: nil },
    { id: 4, name: "Lakeside Dental Group", address: "22 Lakeview Dr, San Jose, CA 95112", website: "lakesidedental.com",
      onboarding: "Pending", last_report: "June 2026", generation: "Pending", send_status: "Not Sent", sent_date: nil },
    { id: 5, name: "Summit Oral Surgery", address: "310 Summit Rd, Sacramento, CA 95814", website: "summitoralsurgery.com",
      onboarding: "Active", last_report: "June 2026", generation: "Failed", send_status: "Not Sent", sent_date: nil },
    { id: 6, name: "Riverside Family Dental", address: "77 Riverside Blvd, Fresno, CA 93650", website: "riversidefamilydental.com",
      onboarding: "Active", last_report: "June 2026", generation: "Ready", send_status: "Sent", sent_date: "Jun 3, 2026" },
    { id: 7, name: "Clear Creek Orthodontics", address: "500 Creek Ln, Bakersfield, CA 93301", website: "clearcreekortho.com",
      onboarding: "Active", last_report: "May 2026", generation: "Ready", send_status: "Sent", sent_date: "Apr 2, 2026" },
    { id: 8, name: "Evergreen Dental Studio", address: "18 Evergreen Way, Stockton, CA 95202", website: "evergreendentalstudio.com",
      onboarding: "Offboarded", last_report: "April 2026", generation: "Pending", send_status: "Not Sent", sent_date: nil }
  ].freeze

  REPORTS = [
    { period: "May 2026", sent_date: "Jun 2, 2026", generation: "Ready", send_status: "Sent", has_preview: true, action: :view },
    { period: "April 2026", sent_date: nil, generation: "Failed", send_status: "Not Sent", has_preview: false, action: :retry,
      error: "Data connection to SEMrush timed out. Please check your connection settings and try again, or contact support if the issue persists." },
    { period: "March 2026", sent_date: nil, generation: "Generating", send_status: "Not Sent", has_preview: false, action: :in_progress },
    { period: "February 2026", sent_date: "Mar 3, 2026", generation: "Ready", send_status: "Sent", has_preview: true, action: :view },
    { period: "January 2026", sent_date: nil, generation: "Pending", send_status: "Not Sent", has_preview: false, action: :awaiting }
  ].freeze

  def index
    @clients = CLIENTS
  end

  def show
    @client = CLIENTS.find { |c| c[:id] == params[:id].to_i } || CLIENTS.first
    @reports = REPORTS
  end

  def new
  end

  def create
    redirect_to clients_path
  end
end
