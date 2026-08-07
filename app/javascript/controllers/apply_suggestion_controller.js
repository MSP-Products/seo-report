import { Controller } from "@hotwired/stimulus"

// Fills a sibling text input with a suggested value on click — used by the
// Edit practice page's GHL location match suggestion. The suggested value is
// always shown as plain text alongside this button too, so the field can
// still be filled in by hand without JavaScript.
export default class extends Controller {
  static values = { value: String }

  apply() {
    // Go up to the service row (px-4 py-3) and find the input field there
    const row = this.element.closest(".px-4.py-3")
    if (row) {
      const input = row.querySelector("input[type=text]")
      if (input) input.value = this.valueValue
    }

    // Remove the suggestion div after applying
    const outcome = this.element.closest('[id^="service_outcome_"]')
    if (outcome) outcome.remove()
  }
}
