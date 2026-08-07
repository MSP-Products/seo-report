# frozen_string_literal: true

class Clients::SyncServicesController < ApplicationController
  include FindsClient

  before_action :require_editor!
  before_action :set_client

  # A plain 200 render here would be a no-op in the browser — Turbo Drive
  # only replaces the page on a redirect or a non-2xx status (CLAUDE.md's
  # "Turbo requires the 422 to replace the form" rule applies here too), so
  # this responds with an actual turbo_stream instead: an immediate
  # "Checking…" placeholder per unlinked service, with the real result
  # following later via SyncClientServicesJob's broadcast.
  def create
    services = SyncServicesChecker.unlinked_services(@client)
    SyncClientServicesJob.perform_later(@client.id)

    render turbo_stream: services.map { |service|
      # Use actual average from last 3-4 checks, or default to 2500ms if no history
      duration_ms = ServiceSyncLog.average_duration_for(service)
      duration_ms = 2500 if duration_ms.zero?

      turbo_stream.replace("service_outcome_#{service}",
        partial: "clients/service_outcome", locals: { service: service, outcome: :pending, duration_ms: duration_ms })
    }
  end
end
