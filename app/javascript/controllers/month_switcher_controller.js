import { Controller } from "@hotwired/stimulus"

// Navigates to the selected report month's own URL (each month is a distinct,
// separately-tokened MonthlyReport — see ReportsController).
export default class extends Controller {
  navigate(event) {
    window.location.href = event.target.value
  }
}
