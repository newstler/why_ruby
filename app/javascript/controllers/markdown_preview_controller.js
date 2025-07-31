import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "previewContainer"]

  connect() {
    this.updatePreview()
    this.syncHeights()
    this.setupScrollSync()
  }

  syncHeights() {
    // Match the heights of textarea and preview
    const textareaHeight = this.inputTarget.offsetHeight
    this.previewTarget.style.height = `${textareaHeight}px`
  }

  setupScrollSync() {
    let syncing = false
    
    // Sync scroll from textarea to preview
    this.inputTarget.addEventListener('scroll', () => {
      if (syncing) return
      syncing = true
      
      const scrollPercentage = this.inputTarget.scrollTop / 
        (this.inputTarget.scrollHeight - this.inputTarget.clientHeight)
      
      this.previewTarget.scrollTop = scrollPercentage * 
        (this.previewTarget.scrollHeight - this.previewTarget.clientHeight)
      
      setTimeout(() => { syncing = false }, 10)
    })
    
    // Sync scroll from preview to textarea
    this.previewTarget.addEventListener('scroll', () => {
      if (syncing) return
      syncing = true
      
      const scrollPercentage = this.previewTarget.scrollTop / 
        (this.previewTarget.scrollHeight - this.previewTarget.clientHeight)
      
      this.inputTarget.scrollTop = scrollPercentage * 
        (this.inputTarget.scrollHeight - this.inputTarget.clientHeight)
      
      setTimeout(() => { syncing = false }, 10)
    })
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