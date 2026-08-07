require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get clients_path

    assert_redirected_to login_path
  end

  test "index lists kept clients, not discarded ones" do
    sign_in_as(role: "admin")
    kept = Client.create!(name: "Kept Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    discarded = Client.create!(name: "Discarded Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    discarded.discard

    get clients_path

    assert_response :success
    assert_select "p", text: kept.name
    assert_select "p", text: discarded.name, count: 0
  end

  test "index filters by search query" do
    sign_in_as(role: "admin")
    match = Client.create!(name: "Willow Dental #{SecureRandom.hex(4)}", onboarding_status: "active")
    other = Client.create!(name: "Oakview Clinic #{SecureRandom.hex(4)}", onboarding_status: "active")

    get clients_path(q: "Willow")

    assert_response :success
    assert_select "p", text: match.name
    assert_select "p", text: other.name, count: 0
  end

  test "index defaults to the active tab and hides offboarded practices" do
    sign_in_as(role: "admin")
    active = Client.create!(name: "Still Here #{SecureRandom.hex(4)}", onboarding_status: "active")
    gone = Client.create!(name: "Moved On #{SecureRandom.hex(4)}", onboarding_status: "active")
    delete client_path(gone)

    get clients_path

    assert_response :success
    assert_select "p", text: active.name
    assert_select "p", text: gone.name, count: 0
  end

  test "index offboarded tab lists only offboarded practices" do
    sign_in_as(role: "admin")
    active = Client.create!(name: "Still Here #{SecureRandom.hex(4)}", onboarding_status: "active")
    gone = Client.create!(name: "Moved On #{SecureRandom.hex(4)}", onboarding_status: "active")
    delete client_path(gone)

    get clients_path(status: "offboarded")

    assert_response :success
    assert_select "p", text: gone.name
    assert_select "p", text: active.name, count: 0
  end

  test "index all tab lists both kept and offboarded practices" do
    sign_in_as(role: "admin")
    active = Client.create!(name: "Still Here #{SecureRandom.hex(4)}", onboarding_status: "active")
    gone = Client.create!(name: "Moved On #{SecureRandom.hex(4)}", onboarding_status: "active")
    delete client_path(gone)

    get clients_path(status: "all")

    assert_response :success
    assert_select "p", text: active.name
    assert_select "p", text: gone.name
  end

  test "index tab counts cover offboarded practices and respect the search query" do
    sign_in_as(role: "admin")
    Client.create!(name: "Willow Active #{SecureRandom.hex(4)}", onboarding_status: "active")
    Client.create!(name: "Willow Pending #{SecureRandom.hex(4)}", onboarding_status: "pending")
    gone = Client.create!(name: "Willow Gone #{SecureRandom.hex(4)}", onboarding_status: "active")
    delete client_path(gone)
    Client.create!(name: "Oakview Elsewhere #{SecureRandom.hex(4)}", onboarding_status: "active")

    get clients_path(q: "Willow")

    assert_response :success
    assert_select "a", text: "All 3"
    assert_select "a", text: "Active 1"
    assert_select "a", text: "Pending 1"
    assert_select "a", text: "Offboarded 1"
  end

  test "index filters by onboarding status" do
    sign_in_as(role: "admin")
    active = Client.create!(name: "Active Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    pending = Client.create!(name: "Pending Practice #{SecureRandom.hex(4)}", onboarding_status: "pending")

    get clients_path(status: "pending")

    assert_response :success
    assert_select "p", text: pending.name
    assert_select "p", text: active.name, count: 0
  end

  test "show renders the overview tab by default" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Overview Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    get client_path(client)

    assert_response :success
    assert_select "h1", text: client.name
    assert_select "a.border-teal-primary", text: "Overview"
  end

  test "show renders an offboarded client so it can be recovered or deleted" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Gone Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.discard

    get client_path(client)

    assert_response :success
    assert_select "h1", text: client.name
    assert_select "p", text: /archived/
  end

  test "new renders the add-client form" do
    sign_in_as(role: "admin")

    get new_client_path

    assert_response :success
    assert_select "input[name=?]", "client[name]"
  end

  test "new pre-fills the name and HubSpot company id when coming from a HubSpot search result" do
    sign_in_as(role: "admin")

    get new_client_path(hubspot_company_id: "18628823830", hubspot_name: "Adams Dental Associates")

    assert_response :success
    assert_select "input[name=?][value=?]", "client[name]", "Adams Dental Associates"
    assert_select "input[value=?]", "18628823830"
  end

  test "create adds a client with just a name" do
    sign_in_as(role: "admin")

    assert_difference "Client.count", 1 do
      post clients_path, params: { client: { name: "Fresh Practice" } }
    end

    client = Client.find_by(name: "Fresh Practice")
    assert_redirected_to client_path(client)
    assert_equal "pending", client.onboarding_status
  end

  test "create with a HubSpot company ID and no name saves with a placeholder name" do
    sign_in_as(role: "admin")

    assert_difference "Client.count", 1 do
      post clients_path, params: {
        client: {
          name: "",
          client_service_links_attributes: {
            "0" => { service: "hubspot", external_id: "company-123" }
          }
        }
      }
    end

    client = Client.find_by!(name: "Syncing from HubSpot…")
    assert_redirected_to client_path(client)
  end

  test "create without a name and without a HubSpot id fails validation" do
    sign_in_as(role: "admin")

    assert_no_difference "Client.count" do
      post clients_path, params: { client: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "create enqueues a HubSpot sync when a company id is present" do
    sign_in_as(role: "admin")

    assert_enqueued_with(job: SyncHubspotClientJob) do
      post clients_path, params: {
        client: {
          name: "Synced Practice",
          client_service_links_attributes: {
            "0" => { service: "hubspot", external_id: "company-456" }
          }
        }
      }
    end
  end

  test "edit renders the practice's current details" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Editable Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    get edit_client_path(client)

    assert_response :success
    assert_select "input[value=?]", client.name
  end

  test "update saves changed practice details" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Old Name #{SecureRandom.hex(4)}", onboarding_status: "active")

    patch client_path(client), params: { client: { name: "New Name" } }

    assert_redirected_to client_path(client)
    assert_equal "New Name", client.reload.name
  end

  test "update does not let onboarding_status, onboarded_at, or ai_seo_enrolled be set directly" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Locked Fields Practice #{SecureRandom.hex(4)}", onboarding_status: "pending")

    patch client_path(client), params: {
      client: { onboarding_status: "active", onboarded_at: "2026-01-01", ai_seo_enrolled: true }
    }

    client.reload
    assert_equal "pending", client.onboarding_status
    assert_nil client.onboarded_at
    assert_not client.ai_seo_enrolled?
  end

  test "update sets a client-service-link's external_id via nested attributes" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Sources Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    link = client.client_service_links.create!(service: "semrush")

    patch client_path(client), params: {
      client: { client_service_links_attributes: { "0" => { id: link.id, external_id: "semrush-123" } } }
    }

    assert_equal "semrush-123", link.reload.external_id
  end

  test "update resets hubspot sync status when the company id changes" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Resync Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    link = client.client_service_links.create!(service: "hubspot", external_id: "old-id",
      last_synced_at: 1.hour.ago, last_sync_error: nil)

    patch client_path(client), params: {
      client: { client_service_links_attributes: { "0" => { id: link.id, external_id: "new-id" } } }
    }

    link.reload
    assert_equal "new-id", link.external_id
    assert_nil link.last_synced_at
  end

  test "destroy discards the client rather than deleting it" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Offboard Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    assert_no_difference "Client.unscoped.count" do
      delete client_path(client)
    end

    assert_redirected_to clients_path
    assert client.reload.discarded?
  end

  test "restore brings an offboarded client back" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Returning Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.discard

    post restore_client_path(client)

    assert_redirected_to client_path(client)
    assert_not client.reload.discarded?
  end

  # Regression: restore used to undiscard without clearing onboarding_status, so a
  # recovered practice was kept-but-still-"offboarded" — matching no status tab at
  # all (the Offboarded tab counts discarded rows only) and vanishing from the list.
  test "restore moves the client back into a status tab that lists it" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Recovered Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    delete client_path(client) # the real offboard path, which also sets the status

    post restore_client_path(client)

    assert_equal "pending", client.reload.onboarding_status
    get clients_path(status: "pending")
    assert_select "p", text: client.name
  end

  # destroy is soft for a live practice and permanent only for an already-offboarded
  # one, so the same button can't skip the reversible step.
  test "destroy permanently deletes a client that is already offboarded" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Gone For Good #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.discard

    delete client_path(client)

    assert_redirected_to clients_path
    assert_nil Client.find_by(id: client.id)
  end

  test "support role can view clients but not create, update, destroy, or restore" do
    sign_in_as(role: "support")
    client = Client.create!(name: "Read Only Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    get clients_path
    assert_response :success

    get new_client_path
    assert_redirected_to root_path

    post clients_path, params: { client: { name: "Should Not Exist" } }
    assert_nil Client.find_by(name: "Should Not Exist")

    patch client_path(client), params: { client: { name: "Hijacked Name" } }
    assert_not_equal "Hijacked Name", client.reload.name

    delete client_path(client)
    assert_not client.reload.discarded?

    client.discard
    post restore_client_path(client)
    assert client.reload.discarded?
  end
end
