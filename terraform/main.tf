#Set provider
provider "google" {
  project = var.project_id
  region  = var.region
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.84.0" # Specify the minimum version you need
    }
  }
}

#Enable necessary APIs
resource "google_project_service" "gcp_services" {
  for_each           = toset(var.gcp_service_list)
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "null_resource" "trigger_on_service_change" {
  # Use a trigger that depends on the state of all google_project_service instances
  triggers = {
    services = sha256(jsonencode([for svc in google_project_service.gcp_services : svc.id]))
  }

  provisioner "local-exec" {
    # This command is just a placeholder. Replace it with the actual command you want to execute.
    command = "sleep 60"
  }

  # Ensure this null_resource depends on all google_project_service instances
  depends_on = [google_project_service.gcp_services]
}