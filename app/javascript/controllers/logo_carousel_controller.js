import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "tooltip"]
  
  connect() {
    console.log("Logo carousel controller connected")
    this.hideTimeout = null
    this.scrollPosition = 0
    this.scrollSpeed = 2.5 // pixels per frame (adjust for desired speed)
    this.isPaused = false
    this.animationFrame = null
    this.currentTooltip = null
    this.currentLogo = null
    this.mouseX = 0
    this.mouseY = 0
    
    // Start the smooth scroll animation
    this.startSmoothScroll()
  }
  
  disconnect() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }
    // Clean up any visible tooltips and logo highlights
    if (this.currentTooltip) {
      this.hideTooltipImmediately(this.currentTooltip)
    }
    if (this.currentLogo) {
      this.removeLogoHighlight(this.currentLogo)
    }
  }
  
  startSmoothScroll() {
    const animate = () => {
      if (!this.isPaused && this.hasTrackTarget) {
        this.scrollPosition += this.scrollSpeed
        
        // Get the width of one set (half the total width since we have 2 sets)
        const trackWidth = this.trackTarget.scrollWidth / 2
        
        // Reset position seamlessly when we've scrolled one full set
        if (this.scrollPosition >= trackWidth) {
          this.scrollPosition = 0
        }
        
        // Apply the transform
        this.trackTarget.style.transform = `translateX(-${this.scrollPosition}px)`
      }
      
      this.animationFrame = requestAnimationFrame(animate)
    }
    
    animate()
  }
  
  pause() {
    this.isPaused = true
  }
  
  resume() {
    this.isPaused = false
  }
  
  showTooltip(event) {
    // Update mouse position
    this.mouseX = event.clientX
    this.mouseY = event.clientY
    
    // Clear any pending hide timeout
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
    
    const logo = event.currentTarget
    const storyId = logo.dataset.storyId
    
    // Hide previous tooltip if showing a different one
    if (this.currentTooltip && this.currentTooltip.dataset.storyId !== storyId) {
      this.hideTooltipImmediately(this.currentTooltip)
      if (this.currentLogo && this.currentLogo !== logo) {
        this.removeLogoHighlight(this.currentLogo)
      }
    }
    
    const tooltip = this.tooltipTargets.find(t => t.dataset.storyId === storyId)
    
    if (tooltip) {
      this.currentTooltip = tooltip
      this.currentLogo = logo
      
      // Highlight the logo
      this.addLogoHighlight(logo)
      
      // Show tooltip
      tooltip.style.display = 'block'
      
      // Position tooltip near mouse with smart positioning
      this.positionTooltip(tooltip)
      
      // Show tooltip with fade
      requestAnimationFrame(() => {
        tooltip.classList.remove("opacity-0", "pointer-events-none")
        tooltip.classList.add("opacity-100")
      })
      
      // Setup tooltip hover and click handlers
      const enterHandler = () => {
        if (this.hideTimeout) {
          clearTimeout(this.hideTimeout)
          this.hideTimeout = null
        }
        this.pause()
        // Keep logo highlighted when hovering tooltip
        if (this.currentLogo) {
          this.addLogoHighlight(this.currentLogo)
        }
      }
      
      const leaveHandler = () => {
        this.hideTooltipDelayed(storyId)
        this.resume()
        // Remove logo highlight when leaving tooltip
        if (this.currentLogo) {
          this.removeLogoHighlight(this.currentLogo)
        }
      }
      
      const clickHandler = (e) => {
        // Navigate to the story URL
        const url = tooltip.dataset.storyUrl
        if (url) {
          // Check if it's a middle click or ctrl/cmd click
          if (e.button === 1 || e.ctrlKey || e.metaKey) {
            // Open in new tab
            window.open(url, '_blank')
          } else {
            // Navigate in same tab
            window.location.href = url
          }
        }
      }
      
      // Remove old handlers to prevent duplicates
      tooltip.removeEventListener('mouseenter', enterHandler)
      tooltip.removeEventListener('mouseleave', leaveHandler)
      tooltip.removeEventListener('click', clickHandler)
      
      // Add new handlers
      tooltip.addEventListener('mouseenter', enterHandler)
      tooltip.addEventListener('mouseleave', leaveHandler)
      tooltip.addEventListener('click', clickHandler)
      
      // Allow clicking on the tooltip
      tooltip.style.pointerEvents = 'auto'
      tooltip.style.cursor = 'pointer'
    }
  }
  
  addLogoHighlight(logo) {
    if (!logo) return
    // Find the SVG within the logo and apply highlight
    const svg = logo.querySelector('.logo-wrapper svg')
    if (svg) {
      svg.style.filter = 'grayscale(0%) opacity(1)'
    }
    logo.classList.add('logo-highlighted')
  }
  
  removeLogoHighlight(logo) {
    if (!logo) return
    // Remove highlight from SVG
    const svg = logo.querySelector('.logo-wrapper svg')
    if (svg) {
      svg.style.filter = ''
    }
    logo.classList.remove('logo-highlighted')
  }
  
  positionTooltip(tooltip) {
    const tooltipRect = tooltip.getBoundingClientRect()
    const tooltipWidth = 320 // w-80
    const tooltipHeight = tooltipRect.height || 250 // Estimate if not yet rendered
    
    // Offset from cursor
    const offsetX = 15
    const offsetY = 15
    
    // Calculate initial position (prefer bottom-right of cursor)
    let left = this.mouseX + offsetX
    let top = this.mouseY + offsetY
    
    // Check if tooltip goes off the right edge
    if (left + tooltipWidth > window.innerWidth - 20) {
      // Position to the left of cursor instead
      left = this.mouseX - tooltipWidth - offsetX
    }
    
    // Check if tooltip goes off the bottom edge
    if (top + tooltipHeight > window.innerHeight - 20) {
      // Position above cursor instead
      top = this.mouseY - tooltipHeight - offsetY
    }
    
    // Ensure tooltip doesn't go off the left edge
    if (left < 20) {
      left = 20
    }
    
    // Ensure tooltip doesn't go off the top edge
    if (top < 20) {
      top = 20
    }
    
    // Apply position
    tooltip.style.left = `${left}px`
    tooltip.style.top = `${top}px`
  }
  
  hideTooltip(event) {
    const storyId = event.currentTarget.dataset.storyId
    // Remove logo highlight when mouse leaves logo
    const logo = event.currentTarget
    this.removeLogoHighlight(logo)
    this.hideTooltipDelayed(storyId)
  }
  
  hideTooltipDelayed(storyId) {
    // Add a small delay to allow mouse to move to tooltip
    this.hideTimeout = setTimeout(() => {
      const tooltip = this.tooltipTargets.find(t => t.dataset.storyId === storyId)
      
      if (tooltip) {
        this.hideTooltipImmediately(tooltip)
        // Clear current logo reference
        if (this.currentLogo) {
          this.removeLogoHighlight(this.currentLogo)
          this.currentLogo = null
        }
      }
    }, 150)
  }
  
  hideTooltipImmediately(tooltip) {
    tooltip.classList.remove("opacity-100")
    tooltip.classList.add("opacity-0", "pointer-events-none")
    
    setTimeout(() => {
      tooltip.style.display = 'none'
      tooltip.style.pointerEvents = 'none'
      tooltip.style.cursor = 'default'
      if (this.currentTooltip === tooltip) {
        this.currentTooltip = null
      }
    }, 200)
  }
}