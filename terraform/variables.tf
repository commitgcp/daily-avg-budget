variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "gcp_service_list" {
  description = "The list of apis necessary for the project"
  type        = list(string)
  default = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "bigquery.googleapis.com",
    "billingbudgets.googleapis.com",
    "discoveryengine.googleapis.com"
  ]
}

variable "emails" {
  type        = list(string)
  description = "List of email addresses for notification channels"
}

variable "function_bucket_name" {
  type        = string
  description = "Name of the bucket in which to hold the function source code"
}

variable "billing_account_id" {
  type        = string
  description = "id of the billing account on which to put a budget"
}

variable "billing_data_export_project_id" {
  type        = string
  description = "id of the project which has the billing export data for the desired billing account"
}

variable "bigquery_dataset" {
  type        = string
  description = "dataset in the billing export project where the billing data is held"
}

variable "bigquery_dataset_table" {
  type        = string
  description = "table in the dataset in the billing export project where the billing data is held"
}

variable "budget_projects" {
  type        = list(string)
  description = "List of projects for which to set up budgets. They must be connected to the billing account provided. The list may be empty."
}

variable "general_billing_account_alerts" {
  type        = string
  description = "Set to ON if want alerts on entire billing account, OFF otherwise"
}

variable "services_by_project" {
  type        = map(list(string))
  description = "A map where each key is a project and its value is a list of services, for setting budgets on service usage per project. If you want to set a bucget on ALL services within a project, leave the value(list) empty."
}

variable "billing_account_services" {
  type        = list(string)
  description = "List of services for which to set up budgets on the entire billing account (for all projects)."
}
