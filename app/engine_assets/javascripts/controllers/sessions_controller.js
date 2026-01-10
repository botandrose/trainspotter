import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["logFile", "showAnonymous"]
  static values = { sessionsUrl: String }

  changeLogFile() {
    window.location.href = this.buildUrl()
  }

  changeShowAnonymous() {
    window.location.href = this.buildUrl()
  }

  buildUrl() {
    const params = new URLSearchParams()
    if (this.hasLogFileTarget) params.set("log_file", this.logFileTarget.value)
    if (this.hasShowAnonymousTarget && this.showAnonymousTarget.checked) {
      params.set("show_anonymous", "1")
    }
    return `${this.sessionsUrlValue}?${params}`
  }

  loadSession(event) {
    const details = event.currentTarget
    if (!details.open || details.dataset.loaded) return

    details.dataset.loaded = "true"
    const sessionId = details.dataset.sessionId
    const content = details.querySelector(".session-requests")

    fetch(`${this.sessionsUrlValue}/${sessionId}/requests`)
      .then(response => response.json())
      .then(data => {
        content.innerHTML = data.requests?.length > 0
          ? data.requests.join("")
          : '<p class="empty-hint">No requests in this session.</p>'
      })
      .catch(() => {
        content.innerHTML = '<p class="error-hint">Failed to load requests.</p>'
      })
  }
}
