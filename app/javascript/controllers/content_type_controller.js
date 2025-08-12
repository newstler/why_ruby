import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "articleFields", 
    "linkFields", 
    "titleField", 
    "titleInput",
    "linkTitleHint", 
    "imageField",
    "imageInput",
    "categoryField",
    "categorySelect",
    "tagsField",
    "tagsInput",
    "logoField",
    "logoInput",
    "logoPreview",
    "logoPreviewWrapper",
    "svgContent",
    "typeButton",
    "uploadArea",
    "urlInput",
    "contentInput",
    "summaryInput"
  ]
  
  connect() {
    console.log("Content type controller connected")
    
    // Check URL parameters for pre-selecting type
    const urlParams = new URLSearchParams(window.location.search)
    const typeParam = urlParams.get('type')
    
    if (typeParam === 'success_story') {
      // Find and click the success story button
      const successButton = this.typeButtonTargets.find(btn => btn.dataset.type === 'success_story')
      if (successButton) {
        successButton.click()
      }
    } else {
      this.toggleFields()
    }
  }
  
  selectType(event) {
    const button = event.currentTarget
    const type = button.dataset.type
    const previousType = this.getCurrentType()
    
    // Update button states
    this.typeButtonTargets.forEach(btn => {
      if (btn === button) {
        btn.classList.remove('bg-gray-200', 'text-gray-700', 'hover:bg-gray-300')
        btn.classList.add('bg-red-600', 'text-white', 'hover:bg-red-700')
      } else {
        btn.classList.remove('bg-red-600', 'text-white', 'hover:bg-red-700')
        btn.classList.add('bg-gray-200', 'text-gray-700', 'hover:bg-gray-300')
      }
    })
    
    // Set hidden input value
    const hiddenInput = this.element.querySelector('input[name="post[post_type]"]')
    if (hiddenInput) {
      hiddenInput.value = type
    }
    
    // Clear fields when switching types
    this.clearFieldsOnTypeChange(previousType, type)
    
    this.toggleFields()
    
    // Dispatch event for form validation after a short delay to ensure DOM updates
    setTimeout(() => {
      this.element.dispatchEvent(new CustomEvent('postTypeChanged', { 
        detail: { postType: type },
        bubbles: true 
      }))
      
      // Also trigger validation directly
      const titleInput = this.element.querySelector('[name="post[title]"]')
      if (titleInput) {
        titleInput.dispatchEvent(new Event('input', { bubbles: true }))
      }
    }, 50)
  }
  
  getCurrentType() {
    const hiddenInput = this.element.querySelector('input[name="post[post_type]"]')
    return hiddenInput ? hiddenInput.value : 'article'
  }
  
  clearFieldsOnTypeChange(previousType, newType) {
    // Don't clear if type hasn't changed
    if (previousType === newType) return
    
    // Clear fields based on what we're switching FROM and TO
    if (previousType === 'success_story') {
      // Clear logo when switching away from success story
      this.clearLogo()
    }
    
    if (previousType === 'link') {
      // Clear URL when switching away from link
      if (this.hasUrlInputTarget) {
        this.urlInputTarget.value = ''
      }
    }
    
    if (previousType === 'article') {
      // Clear image URL when switching away from article
      if (this.hasImageInputTarget) {
        this.imageInputTarget.value = ''
      }
    }
    
    // Clear fields based on what we're switching TO
    if (newType === 'success_story') {
      // Clear category when switching to success story
      if (this.hasCategorySelectTarget) {
        this.categorySelectTarget.value = ''
      }
      // Clear tags
      if (this.hasTagsInputTarget) {
        // This is the hidden field for tags
        const tagsHiddenField = this.element.querySelector('input[name="post[tag_names]"]')
        if (tagsHiddenField) {
          tagsHiddenField.value = ''
        }
        // Clear visible tags in the UI
        const tagContainer = this.element.querySelector('[data-tag-input-target="container"]')
        if (tagContainer) {
          const tags = tagContainer.querySelectorAll('[data-tag-input-target="tag"]')
          tags.forEach(tag => tag.remove())
        }
      }
      // Clear image URL
      if (this.hasImageInputTarget) {
        this.imageInputTarget.value = ''
      }
      // Clear URL
      if (this.hasUrlInputTarget) {
        this.urlInputTarget.value = ''
      }
    } else if (newType === 'link') {
      // Clear content when switching to link
      if (this.hasContentInputTarget) {
        this.contentInputTarget.value = ''
      }
      // Clear logo
      this.clearLogo()
      // Don't clear image URL when switching to link - it can be populated from metadata
    } else if (newType === 'article') {
      // Clear URL when switching to article
      if (this.hasUrlInputTarget) {
        this.urlInputTarget.value = ''
      }
      // Clear logo
      this.clearLogo()
    }
  }
  
  toggleFields() {
    const hiddenInput = this.element.querySelector('input[name="post[post_type]"]')
    const currentType = hiddenInput ? hiddenInput.value : 'article'
    
    // Update title placeholder
    if (this.hasTitleInputTarget) {
      if (currentType === 'success_story') {
        this.titleInputTarget.placeholder = 'Enter company or project name'
      } else {
        this.titleInputTarget.placeholder = 'Enter a descriptive title'
      }
    }
    
    // Show/hide fields based on type
    if (currentType === 'article') {
      this.showArticleFields()
    } else if (currentType === 'link') {
      this.showLinkFields()
    } else if (currentType === 'success_story') {
      this.showSuccessStoryFields()
    }
  }
  
  showArticleFields() {
    // Show article-specific fields
    this.articleFieldsTarget.classList.remove('hidden')
    this.linkFieldsTarget.classList.add('hidden')
    this.titleFieldTarget.classList.remove('hidden')
    
    if (this.hasImageFieldTarget) {
      this.imageFieldTarget.classList.remove('hidden')
    }
    if (this.hasCategoryFieldTarget) {
      this.categoryFieldTarget.classList.remove('hidden')
    }
    if (this.hasTagsFieldTarget) {
      this.tagsFieldTarget.classList.remove('hidden')
    }
    if (this.hasLogoFieldTarget) {
      this.logoFieldTarget.classList.add('hidden')
    }
    if (this.hasLinkTitleHintTarget) {
      this.linkTitleHintTarget.classList.add('hidden')
    }
  }
  
  showLinkFields() {
    // Show link-specific fields
    this.articleFieldsTarget.classList.add('hidden')
    this.linkFieldsTarget.classList.remove('hidden')
    this.titleFieldTarget.classList.remove('hidden')
    
    if (this.hasImageFieldTarget) {
      // Keep image field visible for external links
      this.imageFieldTarget.classList.remove('hidden')
    }
    if (this.hasCategoryFieldTarget) {
      this.categoryFieldTarget.classList.remove('hidden')
    }
    if (this.hasTagsFieldTarget) {
      this.tagsFieldTarget.classList.remove('hidden')
    }
    if (this.hasLogoFieldTarget) {
      this.logoFieldTarget.classList.add('hidden')
    }
    if (this.hasLinkTitleHintTarget) {
      this.linkTitleHintTarget.classList.remove('hidden')
    }
  }
  
  showSuccessStoryFields() {
    // Show success story-specific fields
    this.articleFieldsTarget.classList.remove('hidden')
    this.linkFieldsTarget.classList.add('hidden')
    this.titleFieldTarget.classList.remove('hidden')
    
    if (this.hasImageFieldTarget) {
      this.imageFieldTarget.classList.add('hidden')
    }
    if (this.hasCategoryFieldTarget) {
      this.categoryFieldTarget.classList.add('hidden')
    }
    if (this.hasTagsFieldTarget) {
      this.tagsFieldTarget.classList.add('hidden')
    }
    if (this.hasLogoFieldTarget) {
      this.logoFieldTarget.classList.remove('hidden')
    }
    if (this.hasLinkTitleHintTarget) {
      this.linkTitleHintTarget.classList.add('hidden')
    }
  }
  
  triggerFileUpload(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasLogoInputTarget) {
      this.logoInputTarget.click()
    }
  }
  
  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasUploadAreaTarget) {
      this.uploadAreaTarget.querySelector('div').classList.add('border-red-400', 'bg-red-50')
    }
  }
  
  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasUploadAreaTarget) {
      this.uploadAreaTarget.querySelector('div').classList.remove('border-red-400', 'bg-red-50')
    }
  }
  
  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.hasUploadAreaTarget) {
      this.uploadAreaTarget.querySelector('div').classList.remove('border-red-400', 'bg-red-50')
    }
    
    const files = event.dataTransfer.files
    if (files.length > 0) {
      const file = files[0]
      this.processFile(file)
    }
  }
  
  handleSvgUpload(event) {
    const file = event.target.files[0]
    if (file) {
      this.processFile(file)
    }
  }
  
  processFile(file) {
    // Check if file is SVG
    if (file.type !== 'image/svg+xml') {
      alert('Please select an SVG file')
      if (this.hasLogoInputTarget) {
        this.logoInputTarget.value = ''
      }
      return
    }
    
    // Read file contents
    const reader = new FileReader()
    reader.onload = (e) => {
      let svgContent = e.target.result
      
      // Clean up SVG content - remove XML declarations, DOCTYPE, comments, etc.
      // Remove XML declaration
      svgContent = svgContent.replace(/<\?xml[^>]*\?>/gi, '')
      // Remove DOCTYPE
      svgContent = svgContent.replace(/<!DOCTYPE[^>]*>/gi, '')
      // Remove comments
      svgContent = svgContent.replace(/<!--[\s\S]*?-->/g, '')
      // Extract just the SVG element and its contents
      const svgMatch = svgContent.match(/<svg[^>]*>[\s\S]*<\/svg>/i)
      
      if (!svgMatch) {
        alert('Invalid SVG file - no SVG element found')
        if (this.hasLogoInputTarget) {
          this.logoInputTarget.value = ''
        }
        return
      }
      
      // Use the cleaned SVG content
      svgContent = svgMatch[0].trim()
      
      // Store SVG content in hidden field
      if (this.hasSvgContentTarget) {
        this.svgContentTarget.value = svgContent
        // Trigger validation after logo is added
        this.svgContentTarget.dispatchEvent(new Event('change', { bubbles: true }))
      }
      
      // Hide upload area and show preview
      if (this.hasUploadAreaTarget) {
        this.uploadAreaTarget.classList.add('hidden')
      }
      
      // Show preview wrapper if it exists
      if (this.hasLogoPreviewWrapperTarget) {
        this.logoPreviewWrapperTargets.forEach(wrapper => {
          wrapper.classList.remove('hidden')
        })
      }
      
      // Show preview
      if (this.hasLogoPreviewTarget) {
        this.logoPreviewTargets.forEach(preview => {
          preview.innerHTML = svgContent
          
          // Style the SVG for preview
          const svg = preview.querySelector('svg')
          if (svg) {
            svg.classList.add('w-full', 'h-full', 'max-w-xs', 'max-h-32')
          }
        })
      }
    }
    
    reader.readAsText(file)
  }
  
  removeLogo(event) {
    event.preventDefault()
    this.clearLogo()
  }
  
  updateSelectColor(event) {
    const select = event.target
    if (select.value === '') {
      select.classList.add('placeholder-selected')
    } else {
      select.classList.remove('placeholder-selected')
    }
  }
  
  clearLogo() {
    // Clear the hidden SVG content field
    if (this.hasSvgContentTarget) {
      this.svgContentTarget.value = ''
      // Trigger validation after logo is removed
      this.svgContentTarget.dispatchEvent(new Event('change', { bubbles: true }))
    }
    
    // Clear the file input
    if (this.hasLogoInputTarget) {
      this.logoInputTarget.value = ''
    }
    
    // Hide all preview wrappers
    if (this.hasLogoPreviewWrapperTarget) {
      this.logoPreviewWrapperTargets.forEach(wrapper => {
        wrapper.classList.add('hidden')
      })
    }
    
    // Clear all preview contents
    if (this.hasLogoPreviewTarget) {
      this.logoPreviewTargets.forEach(preview => {
        preview.innerHTML = ''
      })
    }
    
    // Show upload area again
    if (this.hasUploadAreaTarget) {
      this.uploadAreaTarget.classList.remove('hidden')
    }
  }
}