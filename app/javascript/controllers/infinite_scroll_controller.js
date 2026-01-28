import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["entries", "pagination", "loading"]
  static values = {
    url: String,
    page: { type: Number, default: 1 },
    loading: { type: Boolean, default: false }
  }

  connect() {
    this.observeLastEntry()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  observeLastEntry() {
    const options = {
      root: null,
      rootMargin: "200px",
      threshold: 0
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.loadingValue) {
          this.loadMore()
        }
      })
    }, options)

    this.observeSentinel()
  }

  observeSentinel() {
    const sentinel = this.element.querySelector("[data-infinite-scroll-sentinel]")
    if (sentinel) {
      this.observer.observe(sentinel)
    }
  }

  async loadMore() {
    const nextLink = this.paginationTarget?.querySelector('a[rel="next"]')
    if (!nextLink) return

    this.loadingValue = true
    this.showLoading()

    try {
      const response = await fetch(nextLink.href, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)

        // Re-observe after new content is loaded
        setTimeout(() => {
          this.observeSentinel()
        }, 100)
      }
    } catch (error) {
      console.error("Infinite scroll error:", error)
    } finally {
      this.loadingValue = false
      this.hideLoading()
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }
}
