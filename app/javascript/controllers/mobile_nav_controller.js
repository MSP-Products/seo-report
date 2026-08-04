import { Controller } from "@hotwired/stimulus"

// Toggles the off-canvas admin sidebar below the md breakpoint. Above it,
// the panel is always visible (see the md: classes in the view) and this
// controller has nothing to do.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.panelTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.panelTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
  }
}
