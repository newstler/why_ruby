import { Controller } from "@hotwired/stimulus"

// Handles sticky navigation that attaches below the main header on scroll
// Only activates on screens with min-width: 640px AND min-height: 500px
export default class extends Controller {
  static targets = ["nav"]

  connect() {
    this.headerNav = document.querySelector("nav")
    this.placeholder = null
    this.isSticky = false

    // Bind methods once to maintain references for removal
    this.boundHandleScroll = this.handleScroll.bind(this)
    this.boundHandleResize = this.handleResize.bind(this)
    this.boundCheckMediaQuery = this.checkMediaQuery.bind(this)

    // Check if we should enable sticky behavior (not on horizontal phones)
    this.checkMediaQuery()
    this.mediaQueryList = window.matchMedia("(min-width: 640px) and (min-height: 500px)")
    this.mediaQueryList.addEventListener("change", this.boundCheckMediaQuery)

    window.addEventListener("scroll", this.boundHandleScroll, { passive: true })
    window.addEventListener("resize", this.boundHandleResize, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.boundHandleScroll)
    window.removeEventListener("resize", this.boundHandleResize)
    if (this.mediaQueryList) {
      this.mediaQueryList.removeEventListener("change", this.boundCheckMediaQuery)
    }
    this.unstick()
  }

  checkMediaQuery() {
    this.enabled = window.matchMedia("(min-width: 640px) and (min-height: 500px)").matches
    if (!this.enabled) {
      this.unstick()
    } else {
      this.handleScroll()
    }
  }

  handleResize() {
    this.checkMediaQuery()
    if (this.isSticky) {
      // Update position on resize
      this.navTarget.style.left = "0"
      this.navTarget.style.right = "0"
    }
  }

  handleScroll() {
    if (!this.enabled) return

    const headerHeight = this.headerNav ? this.headerNav.offsetHeight : 0
    const navRect = this.isSticky ? this.placeholder.getBoundingClientRect() : this.navTarget.getBoundingClientRect()
    const originalTop = this.isSticky ? this.placeholder.getBoundingClientRect().top : navRect.top

    // Should stick when the nav would scroll past the header
    // Add small buffer to prevent visual jump
    const shouldStick = originalTop <= headerHeight + 8

    if (shouldStick && !this.isSticky) {
      this.stick(headerHeight)
    } else if (!shouldStick && this.isSticky) {
      this.unstick()
    }
  }

  stick(headerHeight) {
    if (this.isSticky) return

    const rect = this.navTarget.getBoundingClientRect()

    // Create placeholder to maintain layout
    this.placeholder = document.createElement("div")
    this.placeholder.style.height = `${rect.height}px`
    const computedStyle = window.getComputedStyle(this.navTarget)
    this.placeholder.style.marginTop = computedStyle.marginTop
    this.placeholder.style.marginBottom = computedStyle.marginBottom
    this.navTarget.parentNode.insertBefore(this.placeholder, this.navTarget)

    // Make nav fixed with gradient matching Tailwind's md:bg-gradient-to-b md:from-gray-50 md:from-85% md:to-transparent
    this.navTarget.style.position = "fixed"
    this.navTarget.style.top = `${headerHeight}px`
    this.navTarget.style.left = "0"
    this.navTarget.style.right = "0"
    this.navTarget.style.zIndex = "40"
    this.navTarget.style.backgroundImage = "linear-gradient(oklch(0.985 0.002 247.839) 85%, transparent 100%)"
    this.navTarget.style.paddingTop = "0.5rem"
    this.navTarget.style.paddingBottom = "2rem" // smaller padding for just nav buttons
    this.navTarget.style.marginTop = "0"

    this.isSticky = true
  }

  unstick() {
    if (!this.isSticky) return

    // Remove placeholder
    if (this.placeholder && this.placeholder.parentNode) {
      this.placeholder.parentNode.removeChild(this.placeholder)
    }
    this.placeholder = null

    // Reset nav styles
    this.navTarget.style.position = ""
    this.navTarget.style.top = ""
    this.navTarget.style.left = ""
    this.navTarget.style.right = ""
    this.navTarget.style.zIndex = ""
    this.navTarget.style.background = ""
    this.navTarget.style.paddingTop = ""
    this.navTarget.style.paddingBottom = ""
    this.navTarget.style.marginTop = ""

    this.isSticky = false
  }
}
