# frozen_string_literal: true

class GbpPhoto < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
end
