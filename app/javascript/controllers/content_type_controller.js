import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["articleFields", "linkFields", "titleField"]
  
  connect() {
    console.log("Content type controller connected")
    this.toggleFields()
  }
  
  toggle(event) {
    this.toggleFields()
  }
  
  toggleFields() {
    const articleRadio = this.element.querySelector('input[value="article"]:checked')
    
    if (articleRadio) {
      this.articleFieldsTarget.classList.remove('hidden')
      this.linkFieldsTarget.classList.add('hidden')
      this.titleFieldTarget.classList.remove('hidden')
    } else {
      this.articleFieldsTarget.classList.add('hidden')
      this.linkFieldsTarget.classList.remove('hidden')
      this.titleFieldTarget.classList.add('hidden')
    }
  }
} 