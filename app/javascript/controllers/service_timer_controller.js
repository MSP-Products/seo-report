import { Controller } from "@hotwired/stimulus"

// Displays a countdown timer showing estimated seconds remaining for a service check
export default class extends Controller {
  static values = { duration: Number }

  connect() {
    this.startTime = Date.now()
    this.updateCountdown()
    this.interval = setInterval(() => this.updateCountdown(), 1000)
  }

  disconnect() {
    if (this.interval) clearInterval(this.interval)
  }

  updateCountdown() {
    const elapsed = Date.now() - this.startTime
    const remaining = Math.max(0, Math.ceil((this.durationValue - elapsed) / 1000))

    const countdown = this.element.querySelector('[data-service-timer-target="countdown"]')
    if (countdown) {
      countdown.textContent = remaining > 0 ? `(${remaining}s left)` : ""
    }
  }
}
