import { Controller } from "@hotwired/stimulus"

// Copies a target element's text to the clipboard, flashing the trigger's
// label to confirm — used by the client Overview tab's report link card.
export default class extends Controller {
  static targets = ["source", "label"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.textContent.trim())

    if (!this.hasLabelTarget) return

    const original = this.labelTarget.textContent
    this.labelTarget.textContent = "Copied"
    setTimeout(() => { this.labelTarget.textContent = original }, 1500)
  }
}
