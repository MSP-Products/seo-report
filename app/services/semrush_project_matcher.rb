# frozen_string_literal: true

# Suggests a SEMrush project_campaign_id for a Client by matching domains
# against the agency's SEMrush projects/campaigns — same "suggestion, not a
# silent auto-assign" contract as GhlLocationMatcher.
#
# Two chained calls, both confirmed live against a real account:
#   1. GET /management/v1/projects — each project has its own url and tools.
#   2. GET /management/v1/projects/{project_id}/tracking/campaigns — each
#      campaign's own "id" field IS ALREADY the full "project_id_campaign_id"
#      string this app stores as external_id (e.g. "30632499_5220001") — no
#      manual concatenation needed. A project can have multiple campaigns
#      tracking different domains, so the campaign's own url is what's
#      matched, not just the project's — the project-level match only
#      narrows which project's campaigns are worth fetching.
#
# Confirmed live: a practice can have more than one project matching the same
# domain (e.g. a "www." variant alongside the bare-domain one), and only the
# project with Position Tracking actually configured (tools includes
# "tracking") has a working campaigns endpoint — the others 404. So every
# domain-matching project is tried, tracking-enabled ones first, and a 404 on
# one project's campaigns call means "not this one," not a hard failure.
class SemrushProjectMatcher
  include NormalizesDomain

  Match = Data.define(:project_campaign_id, :name, :domain)

  BASE_URL = "https://api.semrush.com"

  def initialize(client)
    @client = client
  end

  def call
    target = normalize_domain(@client.website_url)
    return nil if target.blank?

    api_key = AgencyConnection.find_by(service: "semrush")&.credentials&.dig("api_key")
    return if api_key.blank?

    matching_projects(api_key, target).each do |project|
      campaign = fetch_matching_campaign(api_key, project["project_id"], target)
      next unless campaign

      return Match.new(project_campaign_id: campaign["id"], name: project["project_name"], domain: campaign["url"])
    end

    nil
  end

  private

  # Tracking-enabled projects first — the common case needs only one
  # campaigns call instead of hitting a 404 on an untracked duplicate first.
  def matching_projects(api_key, target)
    response = connection.get("/management/v1/projects", { key: api_key })
    JSON.parse(response.body)
      .select { |project| normalize_domain(project["url"]) == target }
      .sort_by { |project| tracking_enabled?(project) ? 0 : 1 }
  end

  def tracking_enabled?(project)
    Array(project["tools"]).any? { |tool| tool["tool"] == "tracking" }
  end

  # Prefers a campaign whose own url matches; falls back to the first
  # campaign on the project if none do (a project can be created with a
  # slightly different url than the campaign actually tracks).
  def fetch_matching_campaign(api_key, project_id, target)
    response = connection.get("/management/v1/projects/#{project_id}/tracking/campaigns", { key: api_key })
    campaigns = JSON.parse(response.body).fetch("campaigns", [])
    campaigns.find { |campaign| normalize_domain(campaign["url"]) == target } || campaigns.first
  rescue Faraday::ResourceNotFound
    nil
  end

  def connection
    Adapters::ConnectionBuilder.build(BASE_URL)
  end
end
