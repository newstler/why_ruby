import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.minHeight = parseInt(getComputedStyle(this.element).minHeight) || 96
    this.resize()

    // Observe visibility changes to resize when element becomes visible
    this.observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) {
        this.resize()
      }
    })
    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  resize() {
    this.element.style.height = "0px"
    const newHeight = Math.max(this.element.scrollHeight, this.minHeight)
    this.element.style.height = newHeight + "px"
  }
}
