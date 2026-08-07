import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }

  connect() {
    document.addEventListener("click", (e) => {
      if (!this.element.contains(e.target)) {
        this.close()
      }
    })
  }
}
