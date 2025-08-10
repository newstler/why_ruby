import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }
  
  connect() {
    // Check URL hash first
    const hash = window.location.hash.substring(1)
    const validTabs = this.tabTargets.map(tab => tab.dataset.tabsName)
    
    if (hash && validTabs.includes(hash)) {
      this.activeValue = hash
    } else if (!this.activeValue) {
      // Default to projects if no hash and no value
      this.activeValue = "projects"
    }
    
    this.updateDisplay()
    
    // Listen for hash changes (browser back/forward)
    this.handleHashChange = this.handleHashChange.bind(this)
    window.addEventListener('hashchange', this.handleHashChange)
  }
  
  disconnect() {
    // Clean up event listeners
    window.removeEventListener('hashchange', this.handleHashChange)
  }
  
  handleHashChange() {
    const hash = window.location.hash.substring(1)
    const validTabs = this.tabTargets.map(tab => tab.dataset.tabsName)
    
    if (hash && validTabs.includes(hash)) {
      this.activeValue = hash
      this.updateDisplay()
    }
  }
  
  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tabsName
    this.activeValue = tabName
    
    // Update URL hash (use empty hash for default tab to keep URL clean)
    if (tabName === "projects") {
      // Remove hash for default tab
      history.pushState(null, null, window.location.pathname + window.location.search)
    } else {
      window.location.hash = tabName
    }
    
    this.updateDisplay()
  }
  
  updateDisplay() {
    // Update tabs
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabsName === this.activeValue
      const badge = tab.querySelector('span:last-child') // Get the badge span
      
      if (isActive) {
        // Active tab styling
        tab.classList.add("text-red-600", "border-red-600")
        tab.classList.remove("text-gray-500", "border-transparent", "hover:text-gray-700")
        tab.setAttribute("aria-selected", "true")
        
        // Update badge styling for active tab
        if (badge) {
          badge.classList.remove("bg-gray-100", "text-gray-700")
          badge.classList.add("bg-red-100", "text-red-700")
        }
      } else {
        // Inactive tab styling
        tab.classList.remove("text-red-600", "border-red-600")
        tab.classList.add("text-gray-500", "border-transparent", "hover:text-gray-700")
        tab.setAttribute("aria-selected", "false")
        
        // Update badge styling for inactive tab
        if (badge) {
          badge.classList.remove("bg-red-100", "text-red-700")
          badge.classList.add("bg-gray-100", "text-gray-700")
        }
      }
    })
    
    // Update panels
    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.tabsName === this.activeValue
      
      if (isActive) {
        panel.classList.remove("hidden")
        panel.setAttribute("aria-hidden", "false")
      } else {
        panel.classList.add("hidden")
        panel.setAttribute("aria-hidden", "true")
      }
    })
  }
}
