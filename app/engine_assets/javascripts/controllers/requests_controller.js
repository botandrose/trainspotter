import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "status", "logFile", "ipFilter", "autoScroll"]
  static values = {
    pollUrl: String,
    rootUrl: String,
    sinceId: String,
    logFile: String,
    ip: String
  }

  connect() {
    this.scrollToBottom()
    this.poll()
  }

  poll() {
    const params = new URLSearchParams()
    params.set("log_file", this.logFileValue)
    if (this.sinceIdValue) params.set("since_id", this.sinceIdValue)
    if (this.ipValue) params.set("ip", this.ipValue)

    fetch(`${this.pollUrlValue}?${params}`)
      .then(response => response.json())
      .then(data => {
        if (data.requests?.length > 0) {
          data.requests.forEach(html => {
            this.listTarget.insertAdjacentHTML("beforeend", html)
          })
          this.scrollToBottom()
          this.element.querySelector(".empty-state")?.remove()
        }
        if (data.since_id) this.sinceIdValue = data.since_id
        this.statusTarget.classList.remove("disconnected")
        this.statusTarget.classList.add("connected")
      })
      .catch(() => {
        this.statusTarget.classList.remove("connected")
        this.statusTarget.classList.add("disconnected")
      })
      .finally(() => setTimeout(() => this.poll(), 1000))
  }

  scrollToBottom() {
    if (this.autoScrollTarget.checked) {
      this.listTarget.scrollTop = this.listTarget.scrollHeight
    }
  }

  changeLogFile() {
    this.logFileValue = this.logFileTarget.value
    window.location.href = this.buildUrl()
  }

  changeIp() {
    this.ipValue = this.ipFilterTarget.value
    window.location.href = this.buildUrl()
  }

  buildUrl() {
    const params = new URLSearchParams()
    params.set("log_file", this.logFileValue)
    if (this.ipValue) params.set("ip", this.ipValue)
    return `${this.rootUrlValue}?${params}`
  }
}
