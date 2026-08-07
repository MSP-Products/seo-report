import { Controller } from "@hotwired/stimulus"

// Removes a service suggestion when the × button is clicked — clears the
// service_outcome div so the admin can reject a match and try manually entering the ID.
export default class extends Controller {
  dismiss() {
    this.element.closest("#service_outcome_" + this.getServiceFromId())
      ?.remove()
  }

  getServiceFromId() {
    // The button is inside #service_outcome_<service>, so climb up to find which service
    const parent = this.element.closest('[id^="service_outcome_"]')
    if (!parent) return ""
    return parent.id.replace("service_outcome_", "")
  }
}
