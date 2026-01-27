import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "counter", "submit"]
  static values = { min: Number, max: Number }

  connect() {
    this.update()
  }

  update() {
    const length = this.inputTarget.value.length
    const min = this.minValue
    const max = this.maxValue

    this.counterTarget.textContent = `${length} / ${min}–${max}`

    if (length < min) {
      this.counterTarget.className = "text-sm mt-1 text-gray-400"
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
      this.submitTarget.classList.remove("cursor-pointer", "hover:bg-red-700")
    } else if (length <= max) {
      this.counterTarget.className = "text-sm mt-1 text-green-600"
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
      this.submitTarget.classList.add("cursor-pointer", "hover:bg-red-700")
    } else {
      this.counterTarget.className = "text-sm mt-1 text-red-500"
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
      this.submitTarget.classList.remove("cursor-pointer", "hover:bg-red-700")
    }
  }
}
