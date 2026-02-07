import { Controller } from "@hotwired/stimulus"

const GEM_PATH = "M56.6.55h86.84c6.79,0,13.13,3.39,16.9,9.04l36.26,54.34c5.26,7.89,4.37,18.37-2.15,25.25l-79.68,84.14c-8.01,8.46-21.49,8.46-29.51,0L5.59,89.18c-6.52-6.88-7.41-17.36-2.15-25.25L39.7,9.59C43.47,3.94,49.81.55,56.6.55Z"

export default class extends Controller {
  static targets = ["container", "loading"]
  static values = {
    dataUrl: String
  }

  connect() {
    this.mapInitialized = false

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting && !this.mapInitialized) {
          this.mapInitialized = true
          this.observer.disconnect()
          this.loadLeaflet()
        }
      })
    }, { rootMargin: "200px" })

    this.observer.observe(this.containerTarget)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  loadLeaflet() {
    if (window.L) {
      this.loadMarkerCluster()
      return
    }

    const css = document.createElement("link")
    css.rel = "stylesheet"
    css.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
    document.head.appendChild(css)

    const script = document.createElement("script")
    script.src = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
    script.onload = () => this.loadMarkerCluster()
    document.head.appendChild(script)
  }

  loadMarkerCluster() {
    if (window.L && window.L.markerClusterGroup) {
      this.initMap()
      return
    }

    const css1 = document.createElement("link")
    css1.rel = "stylesheet"
    css1.href = "https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css"
    document.head.appendChild(css1)

    const css2 = document.createElement("link")
    css2.rel = "stylesheet"
    css2.href = "https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css"
    document.head.appendChild(css2)

    const script = document.createElement("script")
    script.src = "https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js"
    script.onload = () => this.initMap()
    document.head.appendChild(script)
  }

  initMap() {
    this.readyForBoundsUpdate = false

    this.map = L.map(this.containerTarget, {
      center: [30, 10],
      zoom: 2,
      minZoom: 2,
      maxZoom: 15,
      zoomControl: true,
      scrollWheelZoom: false,
      attributionControl: true
    })

    L.tileLayer("https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/">CARTO</a>',
      subdomains: "abcd",
      maxZoom: 20
    }).addTo(this.map)

    setTimeout(() => this.map.invalidateSize(), 100)

    this.map.on("moveend", () => {
      if (!this.readyForBoundsUpdate) return
      this.onBoundsChange()
    })

    this.loadMarkers()
  }

  async loadMarkers() {
    try {
      const response = await fetch(this.dataUrlValue)
      if (!response.ok) throw new Error("Failed to fetch map data")

      const users = await response.json()
      this.hideLoading()
      this.createMarkers(users)
    } catch (error) {
      console.error("Community map error:", error)
      this.hideLoading()
    }
  }

  createMarkers(users) {
    const cluster = L.markerClusterGroup({
      maxClusterRadius: 80,
      spiderfyOnMaxZoom: true,
      spiderfyDistanceMultiplier: 2,
      showCoverageOnHover: false,
      iconCreateFunction: (c) => this.buildClusterIcon(c)
    })

    users.forEach(user => {
      const icon = L.divIcon({
        html: this.buildMarkerHtml(user),
        className: "community-map-marker",
        iconSize: [40, 36],
        iconAnchor: [20, 36]
      })

      const marker = L.marker([user.lat, user.lng], { icon, title: user.name })
      marker.on("click", () => { window.location.href = user.profile_url })
      cluster.addLayer(marker)
    })

    this.map.addLayer(cluster)
    this.readyForBoundsUpdate = true
  }

  buildMarkerHtml(user) {
    const clipId = `map-gem-${user.id}`
    let imageContent
    if (user.avatar_url) {
      imageContent = `<image href="${user.avatar_url}" width="200" height="180" clip-path="url(#${clipId})" preserveAspectRatio="xMidYMid slice"/>`
    } else {
      const initial = user.name.charAt(0).toUpperCase()
      imageContent = `<rect width="200" height="180" fill="#d1d5db" clip-path="url(#${clipId})"/><text x="100" y="100" text-anchor="middle" dominant-baseline="middle" fill="#374151" font-weight="bold" font-size="72">${initial}</text>`
    }

    let badge = ""
    if (user.open_to_work) {
      badge = `<div style="position:absolute;bottom:4px;left:50%;transform:translateX(-50%);background:#dc2626;color:white;font-size:4px;font-weight:bold;padding:0.5px 2.5px;border-radius:9999px;white-space:nowrap;text-transform:uppercase;letter-spacing:0.3px;line-height:1.2;">Open to work</div>`
    }

    return `<div style="cursor:pointer;transition:transform 0.2s;width:40px;height:36px;position:relative;" onmouseenter="this.style.transform='scale(1.3)';this.style.zIndex='10'" onmouseleave="this.style.transform='scale(1)';this.style.zIndex=''"><svg viewBox="0 0 200 180" width="40" height="36" style="overflow:visible;filter:drop-shadow(0 2px 4px rgba(0,0,0,0.25))"><defs><clipPath id="${clipId}"><path d="${GEM_PATH}"/></clipPath></defs>${imageContent}<path d="${GEM_PATH}" fill="none" stroke="white" stroke-width="14"/><path d="${GEM_PATH}" fill="none" stroke="#dc2626" stroke-width="8"/></svg>${badge}</div>`
  }

  buildClusterIcon(cluster) {
    const count = cluster.getChildCount()
    const size = Math.min(60, 36 + Math.log2(count) * 6)
    const height = size * 0.9
    const fontSize = count >= 10 ? 60 : 72

    const html = `<div style="cursor:pointer;width:${size}px;height:${height}px;transition:transform 0.2s;" onmouseenter="this.style.transform='scale(1.15)'" onmouseleave="this.style.transform='scale(1)'"><svg viewBox="0 0 200 180" width="${size}" height="${height}" style="overflow:visible;filter:drop-shadow(0 2px 6px rgba(0,0,0,0.3))"><path d="${GEM_PATH}" fill="#dc2626"/><path d="${GEM_PATH}" fill="none" stroke="white" stroke-width="8"/><text x="100" y="85" text-anchor="middle" dominant-baseline="middle" fill="white" font-weight="bold" font-size="${fontSize}">${count}</text></svg></div>`

    return L.divIcon({
      html,
      className: "community-map-cluster",
      iconSize: [size, height],
      iconAnchor: [size / 2, height / 2]
    })
  }

  onBoundsChange() {
    if (this.boundsTimeout) clearTimeout(this.boundsTimeout)
    this.boundsTimeout = setTimeout(() => this.updateContent(), 300)
  }

  updateContent() {
    const frame = document.getElementById("community-content")
    if (!frame) return

    const baseUrl = this.contentBaseUrl()

    // Preserve current sort/filter params from frame's last navigation or page URL
    const currentSrc = frame.getAttribute("src")
    const params = currentSrc
      ? new URL(currentSrc, window.location.origin).searchParams
      : new URLSearchParams(window.location.search)

    // Clear stale bounds and page (reset to page 1 on bounds change)
    params.delete("south")
    params.delete("north")
    params.delete("west")
    params.delete("east")
    params.delete("page")

    if (this.map.getZoom() >= 3) {
      const bounds = this.map.getBounds()
      params.set("south", bounds.getSouth().toFixed(4))
      params.set("north", bounds.getNorth().toFixed(4))
      params.set("west", bounds.getWest().toFixed(4))
      params.set("east", bounds.getEast().toFixed(4))
    }

    const query = params.toString()
    frame.src = query ? `${baseUrl}?${query}` : baseUrl
  }

  contentBaseUrl() {
    const url = this.dataUrlValue.replace("/map_data", "")
    return url || "/"
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }
}
