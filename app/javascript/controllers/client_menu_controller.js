import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.buttonTarget.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.toggleMenu()
    })

    document.addEventListener("click", (e) => {
      if (!this.element.contains(e.target)) {
        this.hideMenu()
      }
    })
  }

  toggleMenu() {
    if (this.menuTarget.style.display === "none" || this.menuTarget.style.display === "") {
      this.showMenu()
    } else {
      this.hideMenu()
    }
  }

  showMenu() {
    const button = this.buttonTarget
    const buttonRect = button.getBoundingClientRect()
    const menuHeight = this.menuTarget.offsetHeight

    // Position menu above button, centered with right-align for screen edge safety
    this.menuTarget.style.position = "fixed"
    this.menuTarget.style.top = (buttonRect.top - menuHeight - 8) + "px"
    this.menuTarget.style.right = (window.innerWidth - buttonRect.right + 8) + "px"
    this.menuTarget.style.left = "auto"
    this.menuTarget.style.display = "block"
  }

  hideMenu() {
    this.menuTarget.style.display = "none"
  }
}
