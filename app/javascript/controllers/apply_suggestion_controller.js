import { Controller } from "@hotwired/stimulus"

// Fills a sibling text input with a suggested value on click — used by the
// Edit practice page's GHL location match suggestion. The suggested value is
// always shown as plain text alongside this button too, so the field can
// still be filled in by hand without JavaScript.
export default class extends Controller {
  // Named externalId, not value: a Stimulus value called "value" would need the
  // baffling data-apply-suggestion-value-value attribute, which reads like a
  // typo and has already been "corrected" into a bug once.
  static values = { externalId: String }

  apply() {
    // Go up to the service row (px-4 py-3) and find the input field there
    const row = this.element.closest(".px-4.py-3")
    if (row) {
      const input = row.querySelector("input[type=text]")
      if (input) input.value = this.externalIdValue
    }

    // Remove the suggestion div after applying
    const outcome = this.element.closest('[id^="service_outcome_"]')
    if (outcome) outcome.remove()
  }
}
