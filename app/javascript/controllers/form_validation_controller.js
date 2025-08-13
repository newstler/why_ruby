import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["requiredField", "submitButton"]
  static values = { postType: String }
  
  connect() {
    console.log("Form validation controller connected")
    
    // Check if this is a new post (button is initially disabled)
    this.isNewPost = this.hasSubmitButtonTarget && this.submitButtonTarget.disabled
    
    if (this.isNewPost) {
      this.validateForm()
    }
    
    // Listen for post type changes from the content-type controller
    this.element.addEventListener('postTypeChanged', (event) => {
      this.postTypeValue = event.detail.postType
      if (this.isNewPost) {
        this.validateForm()
      }
    })
  }
  
  validateForm() {
    // Only validate for new posts
    if (!this.isNewPost) return
    
    const isValid = this.checkRequiredFields()
    this.updateSubmitButton(isValid)
  }
  
  checkRequiredFields() {
    const postType = this.getCurrentPostType()
    console.log("Checking required fields for post type:", postType)
    let isValid = true
    
    // Title is always required
    const titleInput = this.element.querySelector('[name="post[title]"]')
    if (!titleInput || !titleInput.value.trim()) {
      console.log("Title is missing or empty")
      isValid = false
    }
    
    // Check type-specific required fields
    switch(postType) {
      case 'article':
        // Content is required for articles
        const contentInput = this.element.querySelector('[name="post[content]"]')
        if (!contentInput || !contentInput.value.trim()) {
          console.log("Content is missing or empty")
          isValid = false
        }
        
        // Category is required for articles - only check if field is visible
        const categoryField = this.element.querySelector('#category-field')
        if (categoryField && !categoryField.classList.contains('hidden')) {
          const categorySelect = this.element.querySelector('[name="post[category_id]"]')
          if (!categorySelect || !categorySelect.value) {
            console.log("Category is missing or not selected")
            isValid = false
          }
        }
        break
        
      case 'link':
        // URL is required for links - check if link fields are visible
        const linkFields = this.element.querySelector('#link-fields')
        if (linkFields && !linkFields.classList.contains('hidden')) {
          const urlInput = this.element.querySelector('[name="post[url]"]')
          if (!urlInput || !urlInput.value.trim()) {
            console.log("URL is missing or empty")
            isValid = false
          }
        }
        
        // Category is required for links - only check if field is visible
        const linkCategoryField = this.element.querySelector('#category-field')
        if (linkCategoryField && !linkCategoryField.classList.contains('hidden')) {
          const linkCategorySelect = this.element.querySelector('[name="post[category_id]"]')
          if (!linkCategorySelect || !linkCategorySelect.value) {
            console.log("Category is missing or not selected for link")
            isValid = false
          }
        }
        break
        
      case 'success_story':
        // Logo SVG is required for success stories
        const logoSvgInput = this.element.querySelector('[name="post[logo_svg]"]')
        if (!logoSvgInput || !logoSvgInput.value.trim()) {
          console.log("Logo SVG is missing or empty")
          isValid = false
        }
        
        // Content is required for success stories
        const storyContentInput = this.element.querySelector('[name="post[content]"]')
        if (!storyContentInput || !storyContentInput.value.trim()) {
          console.log("Story content is missing or empty")
          isValid = false
        }
        break
    }
    
    console.log("Form validation result:", isValid)
    return isValid
  }
  
  getCurrentPostType() {
    // Get the current post type from the hidden field
    const hiddenTypeInput = this.element.querySelector('[name="post[post_type]"]')
    return hiddenTypeInput ? hiddenTypeInput.value : 'article'
  }
  
  updateSubmitButton(isValid) {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !isValid
      
      if (isValid) {
        this.submitButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
        this.submitButtonTarget.classList.add('cursor-pointer')
      } else {
        this.submitButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
        this.submitButtonTarget.classList.remove('cursor-pointer')
      }
    }
  }
}
