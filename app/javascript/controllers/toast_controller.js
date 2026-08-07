import { Controller } from "@hotwired/stimulus"

// Auto-dismisses a toast alert after a delay, with a manual close action too.
// The entrance/exit transition is plain CSS (opacity/translate), toggled here.
export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    requestAnimationFrame(() => this.element.classList.remove("opacity-0", "translate-y-2"))
    this.timeout = setTimeout(() => this.close(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  // Removes on transitionend, but falls back to a timeout regardless —
  // transitionend can fail to fire (no visible property change, the tab
  // backgrounded mid-transition, etc.) and a toast that never leaves the DOM
  // is worse than one that disappears a beat early.
  close() {
    this.element.classList.add("opacity-0", "translate-y-2")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    setTimeout(() => this.element.remove(), 300)
  }
}
