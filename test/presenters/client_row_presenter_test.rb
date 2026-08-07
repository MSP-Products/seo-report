require "test_helper"

class ClientRowPresenterTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}", onboarding_status: "active")
  end

  test "initials takes the first letter of the first two words" do
    assert_equal "AD", presenter.initials
  end

  test "service_status_label reports Not linked when there is no link at all" do
    assert_equal "Not linked", presenter.service_status_label("hubspot")
  end

  test "service_status_label reports Not linked when the link has a blank external_id" do
    @client.client_service_links.create!(service: "hubspot", external_id: nil)

    assert_equal "Not linked", presenter.service_status_label("hubspot")
  end

  # A link with an id but no outcome yet is a first sync still in flight.
  test "service_status_label reports Syncing when a linked service has no outcome yet" do
    @client.client_service_links.create!(service: "hubspot", external_id: "18628823830")

    assert_equal "Syncing…", presenter.service_status_label("hubspot")
  end

  test "service_status_label reports Linked once a sync has succeeded" do
    link_hubspot(last_synced_at: 5.minutes.ago)

    assert_equal "Linked", presenter.service_status_label("hubspot")
  end

  # The error wins over a previous success: last_synced_at stays put on failure
  # (SyncClientFromHubspot#record_attempt only moves it forward on success), so a
  # currently-failing sync must not still read as Linked.
  test "service_status_label reports Failed even when an earlier sync succeeded" do
    link_hubspot(last_synced_at: 1.day.ago, last_sync_error: "401 Unauthorized")

    assert_equal "Failed", presenter.service_status_label("hubspot")
  end

  test "service_status_labels covers every known service" do
    labels = presenter.service_status_labels

    assert_equal Service::KEYS, labels.map { |status| status[:service] }
    assert_equal [ "Not linked" ], labels.map { |status| status[:label] }.uniq
  end

  test "hubspot_sync_label mirrors the hubspot service label" do
    link_hubspot(last_synced_at: 5.minutes.ago)

    assert_equal "Linked", presenter.hubspot_sync_label
  end

  test "delivery_label is Stopped for an offboarded practice" do
    @client.update!(onboarding_status: "offboarded")

    assert_equal "Stopped", presenter.delivery_label
  end

  test "delivery_label reports setup complete before the first report exists" do
    assert_equal "Setup complete", presenter.delivery_label
  end

  test "latest_report_label and sublabel fall back cleanly with no reports" do
    assert_equal "Not yet", presenter.latest_report_label
    assert_equal "No reports yet", presenter.latest_report_sublabel
  end

  # The index preloads both associations; every presenter method must read them in
  # memory rather than firing its own query, or the list N+1s once rows multiply.
  test "reads preloaded associations without issuing queries" do
    @client.client_service_links.create!(service: "hubspot", external_id: "18628823830")
    client = Client.includes(:monthly_reports, :client_service_links).find(@client.id)
    row = ClientRowPresenter.new(client)

    assert_no_queries do
      row.initials
      row.service_status_labels
      row.hubspot_sync_label
      row.delivery_label
      row.latest_report_label
      row.latest_report_sublabel
    end
  end

  private

  def presenter
    ClientRowPresenter.new(@client)
  end

  # Two steps deliberately: ClientServiceLink#reset_sync_status wipes both sync
  # columns whenever a hubspot link's external_id changes — including on create —
  # so a sync outcome can only be set afterwards, exactly as the real sync does.
  def link_hubspot(**sync_attributes)
    link = @client.client_service_links.create!(service: "hubspot", external_id: "18628823830")
    link.update!(**sync_attributes)
  end
end
