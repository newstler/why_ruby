import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Check if we're navigating to a comment anchor
    this.highlightTargetComment()
    
    // Listen for Turbo navigation
    document.addEventListener("turbo:load", () => {
      this.highlightTargetComment()
    })
    
    // Listen for hash changes
    window.addEventListener("hashchange", () => {
      this.highlightTargetComment()
    })
  }
  
  highlightTargetComment() {
    // Get the hash from the URL
    const hash = window.location.hash
    
    if (hash && hash.startsWith("#comment-")) {
      // Remove any existing highlight class
      document.querySelectorAll(".comment-highlighting").forEach(el => {
        el.classList.remove("comment-highlighting")
      })
      
      // Find the target comment
      const targetComment = document.querySelector(hash)
      
      if (targetComment) {
        // Find the comment content within the target
        const commentContent = targetComment.querySelector(".comment-content")
        
        if (commentContent) {
          // Add highlighting class
          commentContent.classList.add("comment-highlighting")
          
          // Remove the class after animation completes
          setTimeout(() => {
            commentContent.classList.remove("comment-highlighting")
          }, 1000)
        }
      }
    }
  }
}
