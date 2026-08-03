# frozen_string_literal: true

class ClientKeyword < ApplicationRecord
  # Associations
  belongs_to :client
  has_many :report_keyword_rankings, foreign_key: :keyword_id, dependent: :destroy

  # Validations
  #
  # No uniqueness validation here, deliberately: SemrushAdapter uses
  # create_or_find_by! for race-safety against a concurrent retry, which
  # relies on catching the DB's unique index violation directly. A
  # validates :uniqueness check would raise RecordInvalid on the initial
  # SELECT before that rescue-and-retry path ever runs, defeating it. The
  # unique index on (client_id, keyword) is the actual invariant; normalize_keyword
  # below is what makes a plain index (case-sensitive at the DB level) sufficient.
  validates :keyword, presence: true

  # Callbacks
  before_validation :normalize_keyword

  # Scopes
  scope :active, -> { where(active: true) }

  private

  # SemrushAdapter auto-creates one of these per tracked phrase every report
  # run — normalizing here, not just in the adapter, is what actually
  # guarantees no duplicate rows accumulate for the same keyword over time
  # regardless of stray casing/whitespace in what SEMrush returns.
  def normalize_keyword
    self.keyword = keyword.strip.downcase if keyword.present?
  end
end
