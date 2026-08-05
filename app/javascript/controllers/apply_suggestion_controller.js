import { Controller } from "@hotwired/stimulus"

// Fills a sibling text input with a suggested value on click — used by the
// Edit practice page's GHL location match suggestion. The suggested value is
// always shown as plain text alongside this button too, so the field can
// still be filled in by hand without JavaScript.
export default class extends Controller {
  static values = { value: String }

  apply() {
    this.element.closest(".flex-wrap").querySelector("input[type=text]").value = this.valueValue
  }
}
