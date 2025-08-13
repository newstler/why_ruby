import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["url", "title", "summary", "image", "preview", "fetchButton", "loading", "duplicateWarning"]
  
  connect() {
    console.log("Link metadata controller connected")
    this.checkTimeout = null
  }
  
  async fetchMetadata() {
    const url = this.urlTarget.value
    
    if (!url || !this.isValidUrl(url)) {
      return
    }
    
    // Hide duplicate warning
    this.hideDuplicateWarning()
    
    // Show loading state
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove('hidden')
    }
    
    try {
      const response = await fetch('/posts/fetch_metadata', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ url: url })
      })
      
      const data = await response.json()
      
      if (data.duplicate) {
        this.showDuplicateWarning(data.existing_post)
      } else if (data.success) {
        this.updateFields(data.metadata)
        this.showPreview(data.metadata)
      } else {
        console.error('Failed to fetch metadata:', data.error)
      }
    } catch (error) {
      console.error('Error fetching metadata:', error)
    } finally {
      // Hide loading state
      if (this.hasLoadingTarget) {
        this.loadingTarget.classList.add('hidden')
      }
    }
  }
  
  updateFields(metadata) {
    // Find form fields in the parent form
    const form = this.element.closest('form')
    
    if (metadata.title) {
      const titleField = form.querySelector('[data-link-metadata-target="title"]')
      if (titleField) {
        titleField.value = metadata.title
        // Trigger input event to activate form validation
        titleField.dispatchEvent(new Event('input', { bubbles: true }))
      }
    }
    
    if (metadata.summary && this.hasSummaryTarget) {
      this.summaryTarget.value = metadata.summary
      // Trigger input event to activate form validation
      this.summaryTarget.dispatchEvent(new Event('input', { bubbles: true }))
    }
    
    if (metadata.image_url) {
      const imageField = form.querySelector('[data-link-metadata-target="image"]')
      if (imageField) {
        imageField.value = metadata.image_url
        // Trigger input event to activate form validation
        imageField.dispatchEvent(new Event('input', { bubbles: true }))
      }
    }
  }
  
  showPreview(metadata) {
    if (!this.hasPreviewTarget) return
    
    const previewHtml = `
      <h4 class="text-sm font-medium text-gray-700 mb-2">Preview:</h4>
      <div class="bg-white border border-gray-300 rounded-lg overflow-hidden hover:shadow-lg transition-shadow">
        ${metadata.image_url ? `
          <div class="aspect-w-16 aspect-h-9">
            <img src="${metadata.image_url}" alt="${metadata.title}" class="w-full h-48 object-cover">
          </div>
        ` : ''}
        <div class="p-4">
          <h3 class="font-semibold text-lg mb-2">${metadata.title || 'No title'}</h3>
          <p class="text-gray-600 text-sm line-clamp-2">${metadata.summary || 'No description available'}</p>
          <p class="text-blue-600 text-sm mt-2 truncate">${this.urlTarget.value}</p>
        </div>
      </div>
    `
    
    this.previewTarget.innerHTML = previewHtml
    this.previewTarget.classList.remove('hidden')
  }
  
  isValidUrl(string) {
    try {
      new URL(string)
      return true
    } catch (_) {
      return false
    }
  }
  
  onUrlPaste(event) {
    // Wait a bit for the paste to complete
    setTimeout(() => {
      if (this.isValidUrl(this.urlTarget.value)) {
        this.checkForDuplicate()
      }
    }, 100)
  }
  
  onUrlInput(event) {
    // Clear previous timeout
    if (this.checkTimeout) {
      clearTimeout(this.checkTimeout)
    }
    
    // Hide warnings/preview if URL is empty
    if (!this.urlTarget.value) {
      this.hideDuplicateWarning()
      this.hidePreview()
      return
    }
    
    // Set a new timeout to check after user stops typing
    this.checkTimeout = setTimeout(() => {
      if (this.isValidUrl(this.urlTarget.value)) {
        this.checkForDuplicate()
      }
    }, 500)
  }
  
  async checkForDuplicate() {
    const url = this.urlTarget.value
    
    if (!url || !this.isValidUrl(url)) {
      return
    }
    
    // Get the post ID if we're editing
    const postId = this.element.closest('form').dataset.postId
    
    try {
      const response = await fetch('/posts/check_duplicate_url', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ 
          url: url,
          exclude_id: postId
        })
      })
      
      const data = await response.json()
      
      if (data.duplicate) {
        this.showDuplicateWarning(data.existing_post)
      } else {
        this.hideDuplicateWarning()
        this.fetchMetadata()
      }
    } catch (error) {
      console.error('Error checking for duplicate:', error)
      // If duplicate check fails, still try to fetch metadata
      this.fetchMetadata()
    }
  }
  
  showDuplicateWarning(existingPost) {
    if (!this.hasDuplicateWarningTarget) return
    
    const warningHtml = `
      <div class="bg-yellow-50 border-l-4 border-yellow-400 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm text-yellow-700">
              This URL has already been posted.
              <a href="${existingPost.url}" class="font-medium underline text-yellow-700 hover:text-yellow-600">
                View "${existingPost.title}"
              </a>
            </p>
          </div>
        </div>
      </div>
    `
    
    this.duplicateWarningTarget.innerHTML = warningHtml
    this.duplicateWarningTarget.classList.remove('hidden')
    
    // Hide preview if showing duplicate warning
    this.hidePreview()
  }
  
  hideDuplicateWarning() {
    if (this.hasDuplicateWarningTarget) {
      this.duplicateWarningTarget.classList.add('hidden')
    }
  }
  
  hidePreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.classList.add('hidden')
    }
  }
} 