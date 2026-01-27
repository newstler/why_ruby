import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot"]

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

    if (this.slideTargets.length <= 1) return
    this.startAutoAdvance()
  }

  disconnect() {
    this.stopAutoAdvance()
  }

  next() {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex + 1) % this.slideTargets.length)
  }

  previous() {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex - 1 + this.slideTargets.length) % this.slideTargets.length)
  }

  goTo(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    if (isNaN(index) || index < 0 || index >= this.slideTargets.length) return
    if (index === this.currentIndex || this.transitioning) return
    this.goToIndex(index)
    this.restartAutoAdvance()
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

    if (this.hasDotTarget) {
      this.dotTargets[this.currentIndex].classList.remove("bg-[#c9a84c]")
      this.dotTargets[this.currentIndex].classList.add("bg-gray-600")
      this.dotTargets[index].classList.add("bg-[#c9a84c]")
      this.dotTargets[index].classList.remove("bg-gray-600")
    }

    this.currentIndex = index
  }

  startAutoAdvance() {
    this.autoAdvanceTimer = setInterval(() => this.next(), 8000)
    this.boundPause = this.pause.bind(this)
    this.boundResume = this.resume.bind(this)
    this.element.addEventListener("mouseenter", this.boundPause)
    this.element.addEventListener("mouseleave", this.boundResume)
  }

  stopAutoAdvance() {
    if (this.autoAdvanceTimer) {
      clearInterval(this.autoAdvanceTimer)
      this.autoAdvanceTimer = null
    }
    if (this.boundPause) {
      this.element.removeEventListener("mouseenter", this.boundPause)
      this.element.removeEventListener("mouseleave", this.boundResume)
    }
  }

  restartAutoAdvance() {
    this.stopAutoAdvance()
    this.startAutoAdvance()
  }

  pause() {
    if (this.autoAdvanceTimer) {
      clearInterval(this.autoAdvanceTimer)
      this.autoAdvanceTimer = null
    }
  }

  resume() {
    if (!this.autoAdvanceTimer && this.slideTargets.length > 1) {
      this.autoAdvanceTimer = setInterval(() => this.next(), 8000)
    }
  }
}
