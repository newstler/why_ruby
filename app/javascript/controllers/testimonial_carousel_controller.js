import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide"]

  connect() {
    this.currentIndex = 0
    this.transitioning = false

    this.slideTargets.forEach((slide, i) => {
      slide.style.transition = "opacity 0.6s ease-in-out"
      if (i === 0) {
        slide.classList.remove("hidden")
        slide.style.opacity = "1"
      } else {
        slide.classList.add("hidden")
        slide.style.opacity = "0"
      }
    })
  }

  next() {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex + 1) % this.slideTargets.length)
  }

  previous() {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex - 1 + this.slideTargets.length) % this.slideTargets.length)
  }

  goToIndex(index) {
    if (index === this.currentIndex) return
    this.transitioning = true

    const current = this.slideTargets[this.currentIndex]
    const next = this.slideTargets[index]

    current.style.opacity = "0"

    setTimeout(() => {
      current.classList.add("hidden")
      next.classList.remove("hidden")
      requestAnimationFrame(() => {
        next.style.opacity = "1"
        this.transitioning = false
      })
    }, 600)

    this.currentIndex = index
  }
}
