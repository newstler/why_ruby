import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    // Ensure menu is hidden by default
    this.close()
  }

  toggle(event) {
    // Prevent event bubbling that might trigger the hide action
    event.stopPropagation()
    
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "true")
    }
  }

  close() {
    this.menuTarget.classList.add("hidden")
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", "false")
    }
  }

  hide(event) {
    // Close menu when clicking outside
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
} 