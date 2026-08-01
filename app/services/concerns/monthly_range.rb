# Shared by Adapters::Base and ReportGenerator, which each independently
# need "the calendar month containing this date, as a Range" and otherwise
# had their own copy of the same beginning_of_month..end_of_month logic.
module MonthlyRange
  def month_range_for(date)
    start_of_month = date.beginning_of_month
    start_of_month..start_of_month.end_of_month
  end
end
