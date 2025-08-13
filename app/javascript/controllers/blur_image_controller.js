import { Controller } from "@hotwired/stimulus"

// Controller for blur-up image loading effect
// NOTE: Currently disabled due to Turbo navigation issues
// Keeping as no-op to avoid errors if still referenced
export default class extends Controller {
  static targets = ["image"]
  
  connect() {
    // No-op - blur loading disabled for Turbo compatibility
    // Images now load directly without blur effect
  }
  
  imageLoaded() {
    // No-op
  }
  
  disconnect() {
    // No-op
  }
}