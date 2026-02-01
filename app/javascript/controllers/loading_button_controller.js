import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "spinner"]

  connect() {
    this.element.addEventListener("submit", this.handleSubmit.bind(this))
  }

  handleSubmit() {
    if (this.hasIconTarget) {
      this.iconTarget.classList.add("hidden")
    }
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove("hidden")
    }
    const button = this.element.querySelector("button")
    if (button) {
      button.disabled = true
      button.classList.add("pointer-events-none", "opacity-70")
    }
  }
}
