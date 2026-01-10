import * as Turbo from "@hotwired/turbo"

window.trainspotterAutoScroll = true

document.addEventListener("turbo:before-stream-render", (event) => {
  document.getElementById("connection-status")?.classList.add("connected")
  document.getElementById("connection-status")?.classList.remove("disconnected")

  if (window.trainspotterAutoScroll && event.target.action === "append") {
    requestAnimationFrame(() => {
      const list = document.getElementById("request-list")
      if (list) list.scrollTop = list.scrollHeight
    })
  }
})

document.addEventListener("turbo:load", () => {
  const source = document.querySelector("turbo-stream-source")
  if (source) {
    source.addEventListener("error", () => {
      document.getElementById("connection-status")?.classList.remove("connected")
      document.getElementById("connection-status")?.classList.add("disconnected")
    })
  }
})
