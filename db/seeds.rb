# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Demo data for the public report page, replicating the 3 reference Lovable prototypes
# (seoreport1/2/3.lovable.app) so /reports/:access_token can be visually checked against
# them. Re-running this file replaces the 3 demo clients (idempotent by name).

REPORT_MONTH = Date.new(2026, 6, 1)

# keyword => [intent, serp_features, keyword_difficulty, potential_traffic, growth]
KEYWORD_DEFS = {
  "cosmetic dentistry" => [ "C", 5, 87, 0.00, 0.00 ],
  "dentist near me" => [ "T", 5, 57, 0.81, 0.06 ],
  "dentist ventura" => [ "C", 5, 47, 0.81, 0.06 ],
  "dental cleaning" => [ "C", 6, 43, 0.00, 0.00 ],
  "dental crowns" => [ "I", 6, 61, 0.00, 0.00 ],
  "dental implants" => [ "I", 7, 92, 0.00, 0.00 ],
  "dental implants in ventura ca" => [ "C", 5, 0, 0.11, 0.06 ],
  "root canal" => [ "I C", 7, 57, 0.00, 0.00 ],
  "dental office ventura" => [ "C", 5, 39, 0.04, 0.01 ],
  "dentist" => [ "C", 4, 74, 0.32, 0.11 ],
  "dentist in ventura ca" => [ "C", 4, 47, 0.00, 0.00 ],
  "ventura dentist" => [ "C", 3, 38, 0.27, 0.02 ],
  "ventura dentists" => [ "C", 5, 44, 0.00, 0.00 ],
  "dentist ventura ca" => [ "C", 5, 36, 0.05, 0.00 ],
  "cosmetic dentist" => [ "C", 4, 64, 0.00, 0.00 ]
}.freeze

# keyword => starting position, used for the first-report (baseline) client
BASELINE_POSITIONS = {
  "cosmetic dentistry" => 11, "dentist near me" => 7, "dentist ventura" => 7,
  "dental cleaning" => nil, "dental crowns" => nil, "dental implants" => nil,
  "dental implants in ventura ca" => 12, "root canal" => nil,
  "dental office ventura" => 6, "dentist" => 11, "dentist in ventura ca" => 7,
  "ventura dentist" => 8, "ventura dentists" => 7, "dentist ventura ca" => 7,
  "cosmetic dentist" => nil
}.freeze

# keyword => [previous position, current position], used for ongoing-report clients
ONGOING_POSITIONS = {
  "cosmetic dentistry" => [ 24, 11 ], "dentist near me" => [ 9, 7 ], "dentist ventura" => [ 8, 7 ],
  "dental cleaning" => [ nil, nil ], "dental crowns" => [ nil, nil ], "dental implants" => [ nil, nil ],
  "dental implants in ventura ca" => [ 12, 12 ], "root canal" => [ nil, nil ],
  "dental office ventura" => [ 5, 6 ], "dentist" => [ 10, 11 ], "dentist in ventura ca" => [ 6, 7 ],
  "ventura dentist" => [ 7, 8 ], "ventura dentists" => [ 6, 7 ], "dentist ventura ca" => [ 5, 7 ],
  "cosmetic dentist" => [ 10, nil ]
}.freeze

PAGES_PUBLISHED = [
  { title: "Dental Implants in Ventura, CA", slug: "dental-implants-ventura-ca",
    description: "Everything patients need to know about dental implants at our Ventura practice." },
  { title: "Cosmetic Dentistry Services", slug: "cosmetic-dentistry-ventura",
    description: "An overview of our cosmetic dentistry services for Ventura-area patients." },
  { title: "Ojai, CA — Location Page", slug: "ojai-ca",
    description: "Serving patients in and around Ojai, California." }
].freeze

GBP_POSTS = [
  { title: "Summer Smile Special", published_at: Date.new(2026, 6, 18),
    description: "Announced a limited-time whitening promotion for new and returning patients through the end of July." },
  { title: "Meet Dr. Aiken", published_at: Date.new(2026, 6, 6),
    description: "Shared a short introduction highlighting Dr. Aiken's approach to gentle, patient-first cosmetic dentistry." }
].freeze

def seed_keywords(client, positions_for)
  KEYWORD_DEFS.map do |keyword, (intent, sf, kd, pot, growth)|
    client_keyword = client.client_keywords.create!(
      keyword: keyword, intent: intent, serp_features: sf, keyword_difficulty: kd
    )
    { client_keyword: client_keyword, potential_traffic: pot, growth: growth, positions: positions_for.call(keyword) }
  end
end

def seed_pages(client, monthly_report)
  PAGES_PUBLISHED.each do |page|
    sitemap_page = client.sitemap_pages.create!(
      url: "https://#{client.website_url}/#{page[:slug]}/",
      title: page[:title],
      meta_description: page[:description],
      first_seen_at: REPORT_MONTH,
      last_seen_at: REPORT_MONTH
    )
    monthly_report.report_pages_published.create!(
      sitemap_page: sitemap_page, url: sitemap_page.url, title: page[:title], description: page[:description]
    )
  end
end

def seed_posts(monthly_report)
  GBP_POSTS.each { |post| monthly_report.gbp_posts.create!(post) }
end

ActiveRecord::Base.transaction do
  [ "Woodside Dental Care", "Bayview Family Dentistry", "Alameda Smiles Dental" ].each do |name|
    Client.unscoped.where(name: name).destroy_all
  end

  # --- Client A: first report after onboarding (baseline, AI SEO enrolled from month one) ---
  client_a = Client.create!(
    name: "Woodside Dental Care",
    address: "10883 Telegraph Rd, Ventura, CA 93004",
    website_url: "www.woodsidedentalcare.net",
    onboarding_status: "active",
    onboarded_at: REPORT_MONTH,
    ai_seo_enrolled: true
  )

  report_a = client_a.monthly_reports.create!(report_month: REPORT_MONTH, is_first_report: true, generated_at: Time.current)

  report_a.create_report_traffic!(
    total_visits: 217, unique_visitors: 59, pages_per_visit: 1.0,
    organic_visits: 59, direct_visits: 92, referral_visits: 41, paid_visits: 25,
    ghl_data_status: "not_connected"
  )
  report_a.create_report_citation!(total_impressions: 900, total_engagements: 253, driving_directions_count: 178, website_clicks_count: 75)
  ai_a = report_a.create_report_ai_visibility!(
    google_rank: 1, ai_rank: 6, overall_score: 42,
    sentiment_positive_pct: 56, sentiment_neutral_pct: 44, sentiment_negative_pct: 0,
    citation_own_site_pct: 57, citation_listings_pct: 27, citation_reputation_pct: 13, citation_third_party_pct: 3
  )
  { chatgpt: 40, google_ai_overview: 48, ai_mode: 38, gemini: 44 }.each do |platform, score|
    ai_a.report_ai_platform_scores.create!(platform: platform, score: score)
  end
  report_a.create_report_gbp_summary!(total_reviews: 312, average_rating: 4.7, new_positive_reviews: 3, new_negative_reviews: 0, needs_photos: false)
  seed_posts(report_a)
  [
    { author_name: "Jessica M.", posted_at: Date.new(2026, 6, 27), rating: 5, sentiment: "positive", needs_action: false,
      body: "This was my first visit and I have to say I was impressed. Everybody there was so nice and cordial. Dr Aiken and her assistant were fantastic!" },
    { author_name: "Ramon S.", posted_at: Date.new(2026, 6, 19), rating: 5, sentiment: "positive", needs_action: false,
      body: "Cleaning was quick and thorough, and the front desk made booking my next visit easy." },
    { author_name: "Priya K.", posted_at: Date.new(2026, 6, 11), rating: 4, sentiment: "positive", needs_action: false,
      body: "Great care overall — office was running a little behind but the hygienist was excellent." }
  ].each { |review| report_a.gbp_reviews.create!(review) }
  report_a.gbp_photos.create!([
    { image_url: "https://placehold.co/400x400?text=Office", caption: "Front desk" },
    { image_url: "https://placehold.co/400x400?text=Team", caption: "Team photo" }
  ])
  seed_pages(client_a, report_a)
  seed_keywords(client_a, ->(keyword) { { position: BASELINE_POSITIONS.fetch(keyword), previous_position: nil } }).each do |row|
    report_a.report_keyword_rankings.create!(
      keyword: row[:client_keyword], potential_traffic: row[:potential_traffic], growth: row[:growth],
      position: row[:positions][:position], previous_position: row[:positions][:previous_position]
    )
  end

  # --- Client B: ongoing report, has revenue via GHL, not doing AI SEO, negative review + needs photos ---
  client_b = Client.create!(
    name: "Bayview Family Dentistry",
    address: "4420 Bayview Ave, Bayview, CA 94015",
    website_url: "www.bayviewfamilydentistry.com",
    onboarding_status: "active",
    onboarded_at: REPORT_MONTH - 6.months,
    ai_seo_enrolled: false
  )

  report_b = client_b.monthly_reports.create!(report_month: REPORT_MONTH, is_first_report: false, generated_at: Time.current)

  report_b.create_report_traffic!(
    total_visits: 217, unique_visitors: 59, pages_per_visit: 1.0,
    organic_visits: 59, direct_visits: 92, referral_visits: 41, paid_visits: 25,
    appointments_booked: 37, estimated_revenue: 18_400.00, ghl_data_status: "connected"
  )
  report_b.create_report_citation!(
    total_impressions: 900, previous_impressions: 818, total_engagements: 253, previous_engagements: 250,
    driving_directions_count: 178, website_clicks_count: 75
  )
  report_b.create_report_highlight!(
    summary_text: "Great month! You welcomed 217 visits to your website, with patients finding you directly " \
      "and through organic search. Your Google Business Profile picked up 6 positive reviews and stayed at a " \
      "strong 4.7-star average, while your keyword rankings kept climbing — \"cosmetic dentistry\" moved up " \
      "13 spots and several local search terms held first-page positions. The posts, photos, and review " \
      "activity you put in this month are helping more patients discover and trust Bayview Family Dentistry.",
    generated_at: Time.current, model_used: "claude-haiku-4-5"
  )
  report_b.create_report_gbp_summary!(total_reviews: 312, average_rating: 4.7, new_positive_reviews: 6, new_negative_reviews: 2, needs_photos: true)
  seed_posts(report_b)
  [
    { author_name: "Jessica M.", posted_at: Date.new(2026, 6, 27), rating: 5, sentiment: "positive", needs_action: false,
      body: "This was my first visit and I have to say I was impressed. Everybody there was so nice and cordial. Dr Aiken and her assistant were fantastic!" },
    { author_name: "Ramon S.", posted_at: Date.new(2026, 6, 19), rating: 5, sentiment: "positive", needs_action: false,
      body: "Cleaning was quick and thorough, and the front desk made booking my next visit easy." },
    { author_name: "Priya K.", posted_at: Date.new(2026, 6, 11), rating: 2, sentiment: "negative", needs_action: true,
      body: "Waited over 30 minutes past my appointment time and the front desk was dismissive when I asked about the delay. Not the experience I expected." }
  ].each { |review| report_b.gbp_reviews.create!(review) }
  seed_pages(client_b, report_b)
  seed_keywords(client_b, ->(keyword) {
    prev, cur = ONGOING_POSITIONS.fetch(keyword)
    { position: cur, previous_position: prev }
  }).each do |row|
    report_b.report_keyword_rankings.create!(
      keyword: row[:client_keyword], potential_traffic: row[:potential_traffic], growth: row[:growth],
      position: row[:positions][:position], previous_position: row[:positions][:previous_position]
    )
  end

  # --- Client C: ongoing report, no revenue (no scheduler), doing AI SEO, all-positive reviews ---
  client_c = Client.create!(
    name: "Alameda Smiles Dental",
    address: "1290 Park St, Alameda, CA 94501",
    website_url: "www.alamedasmilesdental.com",
    onboarding_status: "active",
    onboarded_at: REPORT_MONTH - 6.months,
    ai_seo_enrolled: true
  )

  report_c = client_c.monthly_reports.create!(report_month: REPORT_MONTH, is_first_report: false, generated_at: Time.current)

  report_c.create_report_traffic!(
    total_visits: 217, unique_visitors: 59, pages_per_visit: 1.0,
    organic_visits: 59, direct_visits: 92, referral_visits: 41, paid_visits: 25,
    ghl_data_status: "not_connected"
  )
  report_c.create_report_citation!(
    total_impressions: 900, previous_impressions: 818, total_engagements: 253, previous_engagements: 250,
    driving_directions_count: 178, website_clicks_count: 75
  )
  ai_c = report_c.create_report_ai_visibility!(
    google_rank: 1, ai_rank: 6, overall_score: 26, previous_score: 23,
    sentiment_positive_pct: 56, sentiment_neutral_pct: 44, sentiment_negative_pct: 0,
    citation_own_site_pct: 57, citation_listings_pct: 27, citation_reputation_pct: 13, citation_third_party_pct: 3
  )
  { chatgpt: 24, google_ai_overview: 30, ai_mode: 20, gemini: 28 }.each do |platform, score|
    ai_c.report_ai_platform_scores.create!(platform: platform, score: score)
  end
  report_c.create_report_highlight!(
    summary_text: "Great month! You welcomed 217 visits to your website, with patients finding you directly " \
      "and through organic search. Your Google Business Profile picked up 6 positive reviews and stayed at a " \
      "strong 4.7-star average, while your keyword rankings kept climbing — \"cosmetic dentistry\" moved up " \
      "13 spots and several local search terms held first-page positions. The posts, photos, and review " \
      "activity you put in this month are helping more patients discover and trust Alameda Smiles Dental.",
    ai_seo_summary_text: "On the AI search side, you're still building presence — currently a 26/100 visibility " \
      "score — but the trend is ticking up (+3 this month) and we have room to grow how often ChatGPT, Gemini, " \
      "and Google's AI answers mention your practice.",
    generated_at: Time.current, model_used: "claude-haiku-4-5"
  )
  report_c.create_report_gbp_summary!(total_reviews: 312, average_rating: 4.7, new_positive_reviews: 6, new_negative_reviews: 0, needs_photos: false)
  seed_posts(report_c)
  [
    { author_name: "Jessica M.", posted_at: Date.new(2026, 6, 27), rating: 5, sentiment: "positive", needs_action: false,
      body: "This was my first visit and I have to say I was impressed. Everybody there was so nice and cordial. Dr Aiken and her assistant were fantastic!" },
    { author_name: "Ramon S.", posted_at: Date.new(2026, 6, 19), rating: 5, sentiment: "positive", needs_action: false,
      body: "Cleaning was quick and thorough, and the front desk made booking my next visit easy." },
    { author_name: "Priya K.", posted_at: Date.new(2026, 6, 11), rating: 5, sentiment: "positive", needs_action: false,
      body: "Great care overall — office was running a little behind but the hygienist was excellent." }
  ].each { |review| report_c.gbp_reviews.create!(review) }
  report_c.gbp_photos.create!([
    { image_url: "https://placehold.co/400x400?text=Office", caption: "Front desk" },
    { image_url: "https://placehold.co/400x400?text=Team", caption: "Team photo" }
  ])
  seed_pages(client_c, report_c)
  seed_keywords(client_c, ->(keyword) {
    prev, cur = ONGOING_POSITIONS.fetch(keyword)
    { position: cur, previous_position: prev }
  }).each do |row|
    report_c.report_keyword_rankings.create!(
      keyword: row[:client_keyword], potential_traffic: row[:potential_traffic], growth: row[:growth],
      position: row[:positions][:position], previous_position: row[:positions][:previous_position]
    )
  end

  puts "Seeded demo reports:"
  puts "  Woodside Dental Care (first report):     /reports/#{report_a.access_token}"
  puts "  Bayview Family Dentistry (revenue+neg):  /reports/#{report_b.access_token}"
  puts "  Alameda Smiles Dental (AI SEO enrolled):  /reports/#{report_c.access_token}"
end
