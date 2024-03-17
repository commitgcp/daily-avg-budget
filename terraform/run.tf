locals {
  function_hash = filesha256("../function/main.py.tpl")
}

resource "google_monitoring_notification_channel" "email_channels" {
  for_each = toset(var.emails)

  display_name = "Email Notification Channel ${each.key}"
  type         = "email"
  labels = {
    "email_address" = each.value
  }

  user_labels = {
    "managed-by" = "terraform"
  }
  depends_on = [null_resource.trigger_on_service_change]
}

#Bucket which holds the Cloud Functions
module "function_bucket" {
  source = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  #  version = "~> 5.0"

  name          = var.function_bucket_name
  project_id    = var.project_id
  location      = var.region
  force_destroy = true
  #  iam_members = [{
  #    role   = "roles/storage.objectUser"
  #    member = "SERVICE_ACCOUNT"
  #  },
  #  {
  #    role   = "roles/storage.objectUser"
  #    member = "SERVICE_ACCOUNT"    
  #  }]
  depends_on = [null_resource.trigger_on_service_change]
}

resource "local_file" "function_config" {
  filename = "../function/main.py"
  content = templatefile("../function/main.py.tpl", {
    project_id                     = var.project_id,
    region                         = var.region,
    channel_full_names             = join(",", [for _, channel in google_monitoring_notification_channel.email_channels : channel.name]),
    billing_account_id             = var.billing_account_id,
    billing_data_export_project_id = var.billing_data_export_project_id,
    bigquery_dataset               = var.bigquery_dataset,
    bigquery_dataset_table         = var.bigquery_dataset_table,
    budget_projects                = join(",", var.budget_projects)
    GENERAL_BILLING_ACCOUNT_ALERTS = var.general_billing_account_alerts
  })
}

data "archive_file" "function_zip" {
  type        = "zip"
  output_path = "/tmp/function.zip"
  source_dir  = "../function"
  excludes    = ["main.py.tpl"]
  depends_on  = [local_file.function_config]
}

resource "google_storage_bucket_object" "function_source" {
  name       = "function-${local.function_hash}.zip"
  bucket     = var.function_bucket_name
  source     = "/tmp/function.zip"
  depends_on = [module.function_bucket, data.archive_file.function_zip]
}

module "function_sa" {
  source = "terraform-google-modules/service-accounts/google"
  #  version    = "~> 4.2.1"
  project_id = var.project_id
  prefix     = "daily-avg-budget"
  names      = ["function-sa"]
  project_roles = [
    "${var.project_id}=>roles/storage.admin",
    "${var.project_id}=>roles/serviceusage.serviceUsageConsumer",
    "${var.billing_data_export_project_id}=>roles/bigquery.user",
    "${var.project_id}=>roles/monitoring.editor"
    #    "${var.project_id}=>roles/pubsub.publisher"
  ]
  depends_on = [null_resource.trigger_on_service_change]
}

resource "google_billing_account_iam_member" "billing_costs_manager" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.costsManager"
  member             = "serviceAccount:${module.function_sa.email}"
  depends_on         = [null_resource.trigger_on_service_change]
}

resource "google_billing_account_iam_member" "billing_viewer" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.viewer"
  member             = "serviceAccount:${module.function_sa.email}"
  depends_on         = [null_resource.trigger_on_service_change]
}

resource "google_bigquery_table_iam_member" "dataset_table_user" {
  project    = var.billing_data_export_project_id
  dataset_id = var.bigquery_dataset
  table_id   = var.bigquery_dataset_table
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${module.function_sa.email}"
  depends_on = [null_resource.trigger_on_service_change]
}

module "function" {
  depends_on = [google_storage_bucket_object.function_source, null_resource.trigger_on_service_change]
  source     = "GoogleCloudPlatform/cloud-functions/google"
  #  version    = "~> 0.4"

  # Required variables
  function_name     = "daily-average-budget-function"
  function_location = var.region
  project_id        = var.project_id
  runtime           = "python312"
  build_env_variables = {
    GOOGLE_FUNCTION_SOURCE = "main.py"
  }
  entrypoint = "main"
  storage_source = {
    bucket     = var.function_bucket_name
    object     = "function-${local.function_hash}.zip"
    generation = null
  }
  service_config = {
    timeout_seconds       = "3600"
    service_account_email = module.function_sa.email
    ingress_settings      = "ALLOW_INTERNAL_ONLY"
    #    available_memory      = "512M"
  }
}

output "function_uri" {
  value       = module.function.function_uri
  description = "The uri of the function."
}

resource "google_service_account" "daily_budget_cloud_scheduler_job_invoker" {
  account_id   = "daily-budget-cloud-scheduler"
  display_name = "Cloud Functions Invoker Service Account"
  depends_on   = [null_resource.trigger_on_service_change]
}

resource "google_project_iam_member" "daily_budget_cloud_scheduler_job_invoker_member" {
  project    = var.project_id # Make sure to define the `project_id` variable or replace it with your actual project ID
  role       = "roles/run.invoker"
  member     = "serviceAccount:${google_service_account.daily_budget_cloud_scheduler_job_invoker.email}"
  depends_on = [null_resource.trigger_on_service_change]
}

resource "google_cloud_scheduler_job" "cloud_run_trigger" {
  name        = "cloud-run-job-trigger"
  description = "Trigger for Cloud Run Job"
  schedule = "0 12 * * *"

  http_target {
    uri         = module.function.function_uri
    http_method = "GET"
    oidc_token {
      service_account_email = google_service_account.daily_budget_cloud_scheduler_job_invoker.email
      # Optionally, you can specify the audience if required by your Cloud Run service
      # audience = "your-cloud-run-service-url"
    }
  }

  time_zone  = "Asia/Jerusalem"
  depends_on = [module.function, null_resource.trigger_on_service_change]
}

