import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="publish-toggle"
export default class extends Controller {
  static targets = ["checkbox", "draftLabel", "publishLabel", "switch", "track"]

  connect() {
    this.updateLabels()
    this.updateSwitchPosition()
  }

  toggle() {
    this.checkboxTarget.checked = !this.checkboxTarget.checked
    this.updateLabels()
    this.updateSwitchPosition()
    this.updateAriaChecked()
  }

  updateLabels() {
    const isPublished = this.checkboxTarget.checked
    
    // Update Draft label
    if (this.hasDraftLabelTarget) {
      if (isPublished) {
        this.draftLabelTarget.classList.remove("text-gray-900")
        this.draftLabelTarget.classList.add("text-gray-500")
      } else {
        this.draftLabelTarget.classList.remove("text-gray-500")
        this.draftLabelTarget.classList.add("text-gray-900")
      }
    }
    
    // Update Publish label
    if (this.hasPublishLabelTarget) {
      if (isPublished) {
        this.publishLabelTarget.classList.remove("text-gray-500")
        this.publishLabelTarget.classList.add("text-gray-900")
      } else {
        this.publishLabelTarget.classList.remove("text-gray-900")
        this.publishLabelTarget.classList.add("text-gray-500")
      }
    }
  }

  updateSwitchPosition() {
    const isPublished = this.checkboxTarget.checked
    
    if (isPublished) {
      this.switchTarget.classList.remove("translate-x-0")
      this.switchTarget.classList.add("translate-x-4")
      this.trackTarget.classList.remove("bg-gray-400")
      this.trackTarget.classList.add("bg-red-600")
    } else {
      this.switchTarget.classList.remove("translate-x-4")
      this.switchTarget.classList.add("translate-x-0")
      this.trackTarget.classList.remove("bg-red-600")
      this.trackTarget.classList.add("bg-gray-400")
    }
  }

  updateAriaChecked() {
    const isPublished = this.checkboxTarget.checked
    this.trackTarget.setAttribute('aria-checked', isPublished.toString())
  }
}
