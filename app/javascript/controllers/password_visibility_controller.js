import { Controller } from "@hotwired/stimulus"

// Toggles password field visibility between password and text types.
// Swaps the eye / eye-off SVG icons accordingly.
export default class extends Controller {
  static targets = ["input", "eyeIcon", "eyeOffIcon"]

  toggle() {
    const isPassword = this.inputTarget.type === "password"
    this.inputTarget.type = isPassword ? "text" : "password"
    this.eyeIconTarget.classList.toggle("hidden", !isPassword)
    this.eyeOffIconTarget.classList.toggle("hidden", isPassword)
  }
}
