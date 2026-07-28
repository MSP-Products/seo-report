# frozen_string_literal: true

class ClientKeyword < ApplicationRecord
  # Associations
  belongs_to :client
  has_many :report_keyword_rankings, foreign_key: :keyword_id, dependent: :destroy

  # Validations
  validates :keyword, presence: true

  # Scopes
  scope :active, -> { where(active: true) }
end
