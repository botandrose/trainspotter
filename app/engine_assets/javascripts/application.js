import { Application } from "@hotwired/stimulus"
import RequestsController from "trainspotter/controllers/requests_controller"
import SessionsController from "trainspotter/controllers/sessions_controller"

const application = Application.start()
application.register("requests", RequestsController)
application.register("sessions", SessionsController)
