import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slide", "dot", "swipeArea", "slidesContainer"]

  connect() {
    this.currentIndex = 0
    this.transitioning = false
    this.paused = false
    this.touchStartX = 0
    this.touchEndX = 0

    this.slideTargets.forEach((slide, i) => {
      if (i === 0) {
        slide.classList.remove("hidden")
        slide.style.opacity = "1"
        slide.style.transform = "translateX(0)"
      } else {
        slide.classList.add("hidden")
        slide.style.opacity = "0"
        slide.style.transform = "translateX(0)"
      }
    })

    this.updateDots()
    this.startAutoplay()
    this.setupSwipeListeners()
  }

  disconnect() {
    this.stopAutoplay()
    this.removeSwipeListeners()
  }

  setupSwipeListeners() {
    this.handleTouchStart = this.handleTouchStart.bind(this)
    this.handleTouchEnd = this.handleTouchEnd.bind(this)

    this.element.addEventListener("touchstart", this.handleTouchStart, { passive: true })
    this.element.addEventListener("touchend", this.handleTouchEnd, { passive: true })
  }

  removeSwipeListeners() {
    this.element.removeEventListener("touchstart", this.handleTouchStart)
    this.element.removeEventListener("touchend", this.handleTouchEnd)
  }

  handleTouchStart(event) {
    this.touchStartX = event.changedTouches[0].screenX
  }

  handleTouchEnd(event) {
    this.touchEndX = event.changedTouches[0].screenX
    this.handleSwipe()
  }

  handleSwipe() {
    const swipeThreshold = 50
    const diff = this.touchStartX - this.touchEndX

    if (Math.abs(diff) < swipeThreshold) return

    if (diff > 0) {
      this.nextWithSlide("left")
    } else {
      this.previousWithSlide("right")
    }
  }

  startAutoplay() {
    this.autoplayTimer = setInterval(() => {
      if (!this.paused) this.next()
    }, 10000)
  }

  stopAutoplay() {
    if (this.autoplayTimer) {
      clearInterval(this.autoplayTimer)
      this.autoplayTimer = null
    }
  }

  resetAutoplay() {
    this.stopAutoplay()
    this.startAutoplay()
  }

  pause() {
    this.paused = true
  }

  resume() {
    this.paused = false
  }

  next() {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex + 1) % this.slideTargets.length, "left")
  }

  previous() {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex - 1 + this.slideTargets.length) % this.slideTargets.length, "right")
  }

  nextWithSlide(direction) {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex + 1) % this.slideTargets.length, direction)
  }

  previousWithSlide(direction) {
    if (this.slideTargets.length <= 1 || this.transitioning) return
    this.goToIndex((this.currentIndex - 1 + this.slideTargets.length) % this.slideTargets.length, direction)
  }

  goToSlide(event) {
    const index = parseInt(event.currentTarget.dataset.slideIndex, 10)
    if (!isNaN(index)) {
      const direction = index > this.currentIndex ? "left" : "right"
      this.goToIndex(index, direction)
    }
  }

  goToIndex(index, direction = "left") {
    if (index === this.currentIndex) return
    this.transitioning = true
    this.resetAutoplay()

    const current = this.slideTargets[this.currentIndex]
    const next = this.slideTargets[index]

    this.slideTransition(current, next, direction)

    this.currentIndex = index
    this.updateDots()
  }

  slideTransition(current, next, direction) {
    const slideOutX = direction === "left" ? "-30px" : "30px"
    const slideInX = direction === "left" ? "30px" : "-30px"
    const container = this.slidesContainerTarget

    const containerHeight = current.offsetHeight
    container.style.position = "relative"
    container.style.height = `${containerHeight}px`

    current.style.position = "absolute"
    current.style.top = "0"
    current.style.left = "0"
    current.style.right = "0"
    current.style.transition = "none"
    current.style.transform = "translateX(0)"

    next.style.position = "absolute"
    next.style.top = "0"
    next.style.left = "0"
    next.style.right = "0"
    next.style.transition = "none"
    next.style.transform = `translateX(${slideInX})`
    next.style.opacity = "0"
    next.classList.remove("hidden")

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        current.style.transition = "transform 0.25s ease-out, opacity 0.25s ease-out"
        next.style.transition = "transform 0.25s ease-out, opacity 0.25s ease-out"

        current.style.transform = `translateX(${slideOutX})`
        current.style.opacity = "0"
        next.style.transform = "translateX(0)"
        next.style.opacity = "1"

        setTimeout(() => {
          current.classList.add("hidden")
          current.style.position = ""
          current.style.top = ""
          current.style.left = ""
          current.style.right = ""
          current.style.transform = ""

          next.style.position = ""
          next.style.top = ""
          next.style.left = ""
          next.style.right = ""

          container.style.position = ""
          container.style.height = ""

          this.transitioning = false
        }, 250)
      })
    })
  }

  updateDots() {
    this.dotTargets.forEach((dot, i) => {
      if (i === this.currentIndex) {
        dot.classList.remove("bg-gray-300")
        dot.classList.add("bg-red-600")
      } else {
        dot.classList.remove("bg-red-600")
        dot.classList.add("bg-gray-300")
      }
    })
  }
}
