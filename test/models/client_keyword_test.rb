require "test_helper"

class ClientKeywordTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Test Practice", onboarding_status: "active", website_url: "example.com")
  end

  test "normalizes the keyword to stripped, downcased text before saving" do
    keyword = @client.client_keywords.create!(keyword: "  Dentist Near Me  ")

    assert_equal "dentist near me", keyword.keyword
  end

  test "the unique index (not a uniqueness validation) is what prevents duplicates, since SemrushAdapter " \
       "relies on create_or_find_by! for race-safety" do
    @client.client_keywords.create!(keyword: "dentist near me")

    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientKeyword.insert!({ client_id: @client.id, keyword: "dentist near me" })
    end
  end

  test "create_or_find_by! resolves to the same row on a second call with the same already-normalized keyword" do
    # SemrushAdapter always strips/downcases a phrase itself before calling
    # create_or_find_by! (see parse_rankings/parse_keyword_overview) — the
    # race-safe fallback (find_by! on the raw attributes) only matches
    # correctly when what's passed in is already normalized, since it
    # doesn't re-run validations/callbacks. This locks in that contract.
    original = @client.client_keywords.create!(keyword: "dentist near me")
    found = @client.client_keywords.create_or_find_by!(keyword: "dentist near me")

    assert_equal original.id, found.id
    assert_equal 1, @client.client_keywords.count
  end

  test "is active by default" do
    keyword = @client.client_keywords.create!(keyword: "dentist near me")

    assert keyword.active?
  end

  test "requires a keyword" do
    keyword = @client.client_keywords.new(keyword: "")

    assert_not keyword.valid?
  end
end
