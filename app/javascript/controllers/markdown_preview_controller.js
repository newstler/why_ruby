import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "previewContainer"]

  connect() {
    this.updatePreview()
  }

  updatePreview() {
    // Clear existing timeout
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Debounce the update
    this.timeout = setTimeout(() => {
      this.performUpdate()
    }, 300)
  }

  performUpdate() {
    const content = this.inputTarget.value
    
    if (content.trim() === "") {
      this.previewTarget.innerHTML = "<p class='text-gray-500'>Preview will appear here as you type...</p>"
      return
    }

    // Send content to server for rendering
    fetch('/posts/preview', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({ content: content })
    })
    .then(response => response.json())
    .then(data => {
      this.previewTarget.innerHTML = data.html
    })
    .catch(error => {
      console.error('Preview error:', error)
    })
  }

  togglePreview() {
    this.previewContainerTarget.classList.toggle('hidden')
  }
} 