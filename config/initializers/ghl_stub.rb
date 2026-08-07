# frozen_string_literal: true

# GHL OAuth stub for local development. On by default in development, because GHL's
# OAuth consent redirect cannot complete against localhost — without it, nothing
# downstream of "Connect to GoHighLevel" is reachable locally at all. Fakes the whole
# flow (consent through data calls) with realistic canned responses.
#
# Opt out with GHL_STUB=false to work against a real connection. Worth knowing when
# reading local results: a stubbed "match found" looks identical to a real one in the
# UI, so GHL behaviour verified locally proves the code path, not the integration.
#
# This works by:
# 1. GhlOauthClient#authorize_url skips the real GHL OAuth URL and returns our callback directly
# 2. All GHL API endpoints are stubbed with WebMock to return realistic data
# 3. Everything downstream (adapters, matchers, etc.) exercises real code paths hitting
#    WebMock's responses instead of the real GHL API
#
# Usage:
#   bin/dev                  # stubbed (the local default)
#   GHL_STUB=false bin/dev   # real GHL, needs credentials + a reachable redirect URI
#   # Click "Connect to GoHighLevel" on the Connections page — it will redirect
#   # straight back without leaving the browser, and Sync services will work against
#   # the stubbed location/calendar/opportunity data. No real GHL credentials needed.

# Kept in step with GhlOauthClient#stub_enabled?'s identical guard.
if Rails.env.development? && ENV["GHL_STUB"] != "false"
  require "webmock"
  WebMock.enable!

  # Only stub GHL endpoints; other services (Yext, SEMrush, HubSpot, GA4) pass through
  # to the real APIs (or fail cleanly if not configured).
  WebMock.disable_net_connect!(
    allow: [ "api.yextapis.com", "api.semrush.com", "api.hubapi.com",
             "www.googleapis.com", "analyticsadmin.googleapis.com", "analyticsdata.googleapis.com",
             "oauth2.googleapis.com" ]
  )

  GHL_COMPANY_ID = "stub-company-123"
  GHL_LOCATION_ID = "stub-location-456"
  GHL_OPPORTUNITY_ID = "stub-opp-789"

  # POST /oauth/token — exchange code for access/refresh tokens
  WebMock.stub_request(:post, "https://services.leadconnectorhq.com/oauth/token")
    .to_return(status: 200, body: {
      access_token: "stub-access-token-#{SecureRandom.hex(16)}",
      refresh_token: "stub-refresh-token-#{SecureRandom.hex(16)}",
      expires_in: 3600,
      token_type: "Bearer",
      companyId: GHL_COMPANY_ID
    }.to_json, headers: { "Content-Type" => "application/json" })

  # POST /oauth/locationToken — mint a location-scoped token
  WebMock.stub_request(:post, "https://services.leadconnectorhq.com/oauth/locationToken")
    .to_return(status: 200, body: {
      access_token: "stub-location-token-#{SecureRandom.hex(16)}",
      token_type: "Bearer"
    }.to_json, headers: { "Content-Type" => "application/json" })

  # GET /locations/search — list agency's locations
  WebMock.stub_request(:get, %r{https://services\.leadconnectorhq\.com/locations/search})
    .to_return(status: 200, body: {
      locations: [
        {
          id: GHL_LOCATION_ID,
          name: "Stub Dental Practice",
          website: "https://www.stubdentalassociates.com",
          email: "info@stub.local",
          phone: "555-0000"
        }
      ]
    }.to_json, headers: { "Content-Type" => "application/json" })

  # GET /calendars/ — list calendars for a location (GblLocationMatcher uses this to check existence)
  WebMock.stub_request(:get, %r{https://services\.leadconnectorhq\.com/calendars/.*})
    .to_return(status: 200, body: {
      calendars: [
        { id: "stub-cal-1", name: "Appointments" }
      ]
    }.to_json, headers: { "Content-Type" => "application/json" })

  # GET /calendars/{id}/events — list events in a calendar
  WebMock.stub_request(:get, %r{https://services\.leadconnectorhq\.com/calendars/[^/]+/events})
    .to_return(status: 200, body: {
      events: [
        {
          id: "stub-evt-1",
          title: "Stub Appointment",
          date: Date.today.to_s,
          startTime: "09:00",
          endTime: "10:00"
        }
      ]
    }.to_json, headers: { "Content-Type" => "application/json" })

  # GET /opportunities/search — list opportunities for a location
  WebMock.stub_request(:get, %r{https://services\.leadconnectorhq\.com/opportunities/search})
    .to_return(status: 200, body: {
      opportunities: [
        {
          id: GHL_OPPORTUNITY_ID,
          status: "won",
          value: 1500.0,
          createdAt: (Date.today - 1.day).to_s,
          updatedAt: Date.today.to_s
        }
      ]
    }.to_json, headers: { "Content-Type" => "application/json" })

  Rails.logger.info "GHL stub enabled: all GHL OAuth + API calls faked locally"
end
