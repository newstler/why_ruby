import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    autoDismiss: { type: Number, default: 5000 }
  }

  connect() {
    if (this.autoDismissValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.autoDismissValue)
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dismiss() {
    this.element.classList.add("opacity-0", "translate-x-full")
    setTimeout(() => this.element.remove(), 300)
  }
}
