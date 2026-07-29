# frozen_string_literal: true

class GbpPost < ApplicationRecord
  # Associations
  belongs_to :report, class_name: "MonthlyReport"
end
