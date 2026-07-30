module Adapters
  # Shared credential resolution + HTTP plumbing for the per-service adapters.
  #
  # Credential resolution: a ClientServiceLink#override_credentials (client-specific)
  # wins over the service-wide AgencyConnection#encrypted_credentials fallback. Both
  # store the same JSON-blob shape (documented per adapter), decrypted transparently
  # via ActiveRecord::Encryption.
  class Base
    # Subclasses set: SERVICE = "hubspot" (must match the `service` enum on
    # AgencyConnection/ClientServiceLink).
    SERVICE = nil

    attr_reader :client, :report_month

    # report_month: the calendar month (a Date, day-of-month ignored) being
    # generated — irrelevant for adapters that only read current-state fields
    # (e.g. HubSpot company properties), required for ones pulling a monthly
    # window of activity (GHL, Yext, SEMrush).
    def initialize(client, report_month: nil)
      @client = client
      @report_month = report_month
    end

    def call
      return Result.failure("no credentials configured for #{self.class::SERVICE}") if credentials.blank?

      perform
    rescue Faraday::Error => e
      Result.failure("#{self.class::SERVICE} request failed: #{e.message}")
    end

    private

    def perform
      raise NotImplementedError, "#{self.class} must implement #perform"
    end

    def client_service_link
      return @client_service_link if defined?(@client_service_link)

      @client_service_link = client.client_service_links.find_by(service: self.class::SERVICE)
    end

    def agency_connection
      @agency_connection ||= AgencyConnection.find_by(service: self.class::SERVICE)
    end

    def credentials
      client_service_link&.credentials.presence || agency_connection&.credentials.presence || {}
    end

    # The client's identifier within the external service (location ID, entity
    # ID, tracked domain, etc.) — configured per client via ClientServiceLink.
    def external_id
      client_service_link&.external_id
    end

    def month_range
      start_of_month = report_month.beginning_of_month
      start_of_month..start_of_month.end_of_month
    end

    def connection(base_url, headers: {})
      Faraday.new(url: base_url, headers: headers) do |f|
        f.request :retry, max: 2, interval: 0.5, backoff_factor: 2,
          exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ]
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end
  end
end
