import { Controller } from "@hotwired/stimulus"

// Warns the user before leaving the page if they have unsaved changes
export default class extends Controller {
  static targets = ["form"]

  connect() {
    this.hasChanges = false

    this.formTarget.addEventListener("change", () => {
      this.hasChanges = true
    })

    // Clear changes when form is submitted
    this.formTarget.addEventListener("submit", () => {
      this.hasChanges = false
    })

    // Warn on browser back/reload
    window.addEventListener("beforeunload", (e) => {
      if (this.hasChanges) {
        e.preventDefault()
        e.returnValue = ""
      }
    })

    // Hook into Turbo's click handler for external links only
    document.addEventListener("click", (e) => {
      const link = e.target.closest("a[href]")
      const isExternalLink = link && !link.closest("form")

      if (isExternalLink && this.hasChanges) {
        if (!confirm("You have unsaved changes. Are you sure you want to leave?")) {
          e.preventDefault()
          e.stopImmediatePropagation()
        }
      }
    }, true)
  }
}
