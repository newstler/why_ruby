import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "input", "hiddenField", "suggestions"]
  
  connect() {
    this.tags = []
    this.selectedSuggestionIndex = -1
    
    // Load existing tags if editing a post
    const existingTagsAttr = this.element.getAttribute('data-tag-input-existing-tags-value')
    
    if (existingTagsAttr && existingTagsAttr !== '[]') {
      try {
        const parsedTags = JSON.parse(existingTagsAttr)
        if (Array.isArray(parsedTags) && parsedTags.length > 0) {
          this.tags = parsedTags
          // Render tags immediately
          this.renderTags()
          this.updateHiddenField()
        }
      } catch (e) {
        console.error("Error parsing existing tags:", e, existingTagsAttr)
      }
    }
    
    // Hide suggestions on click outside
    document.addEventListener("click", this.handleClickOutside.bind(this))
    
    // Make the container focusable and handle clicks
    this.containerTarget.addEventListener("click", this.handleContainerClick.bind(this))
  }
  
  disconnect() {
    document.removeEventListener("click", this.handleClickOutside.bind(this))
    this.containerTarget.removeEventListener("click", this.handleContainerClick.bind(this))
  }
  
  handleContainerClick(event) {
    // If clicking on the container (but not on a tag), focus the input
    if (event.target === this.containerTarget || event.target.closest('.tag-input-wrapper')) {
      this.inputTarget.focus()
    }
  }
  
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }
  
  async handleInput(event) {
    const query = event.target.value.trim()
    
    // Check if user pressed comma or Enter
    if (event.key === "," || event.key === "Enter") {
      event.preventDefault()
      this.addTagFromInput()
      return
    }
    
    // Handle arrow keys for suggestion navigation
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectNextSuggestion()
      return
    }
    
    if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectPreviousSuggestion()
      return
    }
    
    // If query is empty, hide suggestions
    if (query.length === 0) {
      this.hideSuggestions()
      return
    }
    
    // Only search if query has at least 2 characters
    if (query.length < 2) {
      return
    }
    
    // Fetch suggestions from the server
    await this.fetchSuggestions(query)
  }
  
  async fetchSuggestions(query) {
    try {
      const response = await fetch(`/tags/search?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "application/json"
        }
      })
      
      if (response.ok) {
        const suggestions = await response.json()
        this.showSuggestions(suggestions, query)
      }
    } catch (error) {
      console.error("Error fetching tag suggestions:", error)
    }
  }
  
  showSuggestions(suggestions, query) {
    // Clear previous suggestions
    this.suggestionsTarget.innerHTML = ""
    
    // Filter out already selected tags
    const availableSuggestions = suggestions.filter(
      tag => !this.tags.some(t => t.name.toLowerCase() === tag.name.toLowerCase())
    )
    
    if (availableSuggestions.length === 0) {
      // Show option to create new tag if no exact match exists
      const exactMatch = suggestions.some(
        tag => tag.name.toLowerCase() === query.toLowerCase()
      )
      
      if (!exactMatch && query.length > 0) {
        const createOption = document.createElement("div")
        createOption.className = "px-3 py-2 hover:bg-gray-100 cursor-pointer text-sm"
        const createNewText = this.data.get("create-new-text") || "Create new tag:"
        createOption.innerHTML = `${createNewText} <span class="font-semibold">${this.escapeHtml(query)}</span>`
        createOption.dataset.action = "click->tag-input#createTag"
        createOption.dataset.tagName = query
        this.suggestionsTarget.appendChild(createOption)
      } else {
        this.hideSuggestions()
      }
    } else {
      // Show existing tag suggestions
      availableSuggestions.forEach((tag, index) => {
        const suggestionElement = document.createElement("div")
        suggestionElement.className = "px-3 py-2 hover:bg-gray-100 cursor-pointer text-sm"
        suggestionElement.textContent = tag.name
        suggestionElement.dataset.action = "click->tag-input#selectTag"
        suggestionElement.dataset.tagId = tag.id
        suggestionElement.dataset.tagName = tag.name
        suggestionElement.dataset.index = index
        this.suggestionsTarget.appendChild(suggestionElement)
      })
      
      // Add option to create new tag if no exact match
      const exactMatch = availableSuggestions.some(
        tag => tag.name.toLowerCase() === query.toLowerCase()
      )
      
      if (!exactMatch && query.length > 0) {
        const createOption = document.createElement("div")
        createOption.className = "px-3 py-2 hover:bg-gray-100 cursor-pointer text-sm border-t"
        const createNewText = this.data.get("create-new-text") || "Create new tag:"
        createOption.innerHTML = `${createNewText} <span class="font-semibold">${this.escapeHtml(query)}</span>`
        createOption.dataset.action = "click->tag-input#createTag"
        createOption.dataset.tagName = query
        createOption.dataset.index = availableSuggestions.length
        this.suggestionsTarget.appendChild(createOption)
      }
    }
    
    // Show suggestions dropdown
    this.suggestionsTarget.classList.remove("hidden")
    this.selectedSuggestionIndex = -1
  }
  
  hideSuggestions() {
    this.suggestionsTarget.classList.add("hidden")
    this.selectedSuggestionIndex = -1
  }
  
  selectTag(event) {
    const tagId = event.currentTarget.dataset.tagId
    const tagName = event.currentTarget.dataset.tagName
    
    this.addTag({ id: tagId, name: tagName })
    this.inputTarget.value = ""
    this.hideSuggestions()
    this.inputTarget.focus()
  }
  
  createTag(event) {
    const tagName = event.currentTarget.dataset.tagName
    
    // Add tag with null ID (will be created on backend)
    this.addTag({ id: null, name: tagName })
    this.inputTarget.value = ""
    this.hideSuggestions()
    this.inputTarget.focus()
  }
  
  addTagFromInput() {
    const tagName = this.inputTarget.value.trim().replace(/,$/, "").trim()
    
    if (tagName.length === 0) {
      return
    }
    
    // Check if tag already exists in selected tags
    if (this.tags.some(t => t.name.toLowerCase() === tagName.toLowerCase())) {
      this.inputTarget.value = ""
      return
    }
    
    // Add tag with null ID (will be created or found on backend)
    this.addTag({ id: null, name: tagName })
    this.inputTarget.value = ""
    this.hideSuggestions()
  }
  
  addTag(tag) {
    // Check if tag already exists
    if (this.tags.some(t => t.name.toLowerCase() === tag.name.toLowerCase())) {
      return
    }
    
    this.tags.push(tag)
    this.renderTags()
    this.updateHiddenField()
  }
  
  removeTag(event) {
    event.stopPropagation()
    const tagName = event.currentTarget.dataset.tagName
    this.tags = this.tags.filter(t => t.name !== tagName)
    this.renderTags()
    this.updateHiddenField()
    this.inputTarget.focus()
  }
  
  renderTags() {
    // Remove existing tag elements (but not the input wrapper)
    const existingTags = this.containerTarget.querySelectorAll('.tag-chip')
    existingTags.forEach(tag => tag.remove())
    
    // Add tags before the input wrapper
    const inputWrapper = this.containerTarget.querySelector('.tag-input-wrapper')
    if (!inputWrapper) {
      console.error("Could not find input wrapper")
      return
    }
    
    this.tags.forEach(tag => {
      const tagElement = document.createElement("span")
      tagElement.className = "tag-chip inline-flex items-center gap-1 px-2 py-0.5 bg-gray-100 text-gray-700 border border-gray-300 rounded text-sm mr-1.5 my-0.5"
      tagElement.innerHTML = `
        <span>${this.escapeHtml(tag.name)}</span>
        <button type="button" 
                class="ml-0.5 text-gray-500 hover:text-gray-700 focus:outline-none cursor-pointer" 
                data-action="click->tag-input#removeTag"
                data-tag-name="${this.escapeHtml(tag.name)}">
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path>
          </svg>
        </button>
      `
      
      // Insert tag before the input wrapper
      this.containerTarget.insertBefore(tagElement, inputWrapper)
    })
    
    // Update placeholder visibility
    if (this.tags.length > 0) {
      this.inputTarget.placeholder = this.data.get("placeholder-with-tags") || "Add more tags..."
    } else {
      this.inputTarget.placeholder = this.data.get("placeholder") || "Type to search tags or create new ones"
    }
  }
  
  updateHiddenField() {
    // Update hidden field with tag names (backend will handle finding/creating)
    const tagNames = this.tags.map(t => t.name).join(",")
    this.hiddenFieldTarget.value = tagNames
  }
  
  selectNextSuggestion() {
    const suggestions = this.suggestionsTarget.querySelectorAll("[data-index]")
    if (suggestions.length === 0) return
    
    // Remove previous selection
    if (this.selectedSuggestionIndex >= 0) {
      suggestions[this.selectedSuggestionIndex].classList.remove("bg-gray-100")
    }
    
    // Move to next suggestion
    this.selectedSuggestionIndex = (this.selectedSuggestionIndex + 1) % suggestions.length
    suggestions[this.selectedSuggestionIndex].classList.add("bg-gray-100")
  }
  
  selectPreviousSuggestion() {
    const suggestions = this.suggestionsTarget.querySelectorAll("[data-index]")
    if (suggestions.length === 0) return
    
    // Remove previous selection
    if (this.selectedSuggestionIndex >= 0) {
      suggestions[this.selectedSuggestionIndex].classList.remove("bg-gray-100")
    }
    
    // Move to previous suggestion
    this.selectedSuggestionIndex = this.selectedSuggestionIndex <= 0 
      ? suggestions.length - 1 
      : this.selectedSuggestionIndex - 1
    suggestions[this.selectedSuggestionIndex].classList.add("bg-gray-100")
  }
  
  handleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      
      // If a suggestion is selected, choose it
      const suggestions = this.suggestionsTarget.querySelectorAll("[data-index]")
      if (this.selectedSuggestionIndex >= 0 && suggestions[this.selectedSuggestionIndex]) {
        suggestions[this.selectedSuggestionIndex].click()
      } else {
        // Otherwise add the current input as a new tag
        this.addTagFromInput()
      }
    } else if (event.key === ",") {
      event.preventDefault()
      this.addTagFromInput()
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      this.selectNextSuggestion()
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.selectPreviousSuggestion()
    } else if (event.key === "Backspace" && this.inputTarget.value === "" && this.tags.length > 0) {
      // Remove last tag if backspace pressed on empty input
      event.preventDefault()
      this.tags.pop()
      this.renderTags()
      this.updateHiddenField()
    }
  }
  
  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}