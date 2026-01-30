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

    const pill = "text-xs font-medium px-2.5 py-0.5 rounded-full"
    let colorClass
    if (length < min) {
      colorClass = `${pill} bg-gray-100 text-gray-400`
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
      this.submitTarget.classList.remove("cursor-pointer", "hover:bg-red-700")
    } else if (length <= max) {
      colorClass = `${pill} bg-green-100 text-green-700`
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
      this.submitTarget.classList.add("cursor-pointer", "hover:bg-red-700")
    } else {
      colorClass = `${pill} bg-red-100 text-red-600`
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
      this.submitTarget.classList.remove("cursor-pointer", "hover:bg-red-700")
    }

    this.counterTargets.forEach(counter => {
      counter.innerHTML = `${length} <span class="opacity-50">/ ${min}–${max}</span>`
      const responsiveClasses = Array.from(counter.classList).filter(c => c.startsWith('hidden') || c.startsWith('md:') || c.startsWith('lg:'))
      counter.className = colorClass + (responsiveClasses.length ? ' ' + responsiveClasses.join(' ') : '')
    })
  }
}
