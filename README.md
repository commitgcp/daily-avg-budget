# Daily Budget Alert Automation Tool

## Introduction

The purpose of this tool is to quickly set up a Cloud Function (along with all of
the necessary infrastructure) which calculates the daily average spend of a given
billing account, and creates a budget (based on the calculated amount)on the same 
billing account for the following day. The tool also creates a Cloud Scheduler
job which runs every day at 12:00 Israel Standard Time (UTC +2:00) and triggers
the created Cloud Function.

## Pre-requisites

- Make sure that the user running terraform for deploying this tool has the necessary permissions:
    - On project where this tool will be deployed: The user should have the role "Owner".
    - On the project which holds the billing data export: The user should have the role "Project IAM Admin".
    - On the billing account for which budgets will be created: The user should have the role "Billing Account Administrator".
- Create a bucket in your project to store the Terraform state of this tool, if you have not already.
- Have the name of this bucket ready.
- Take the name of your Terraform state bucket and put it in terraform/backend.tf, instead of BUCKET_NAME_GOES_HERE.
- Fill the provided terraform.tfvars.example file with your own values and rename it to terraform.tfvars

## Usage

Once you have filled the terraform.tfvars file with your own values, you can run the following commands to deploy the tool:

1. Initialize the terraform workspace
```bash
terraform init
```

2. Plan the deployment to check what resources will be created/modifed/destroyed
```bash
terraform plan
```

3. Apply the terraform plan and provision the resources
```bash
terraform apply
```

4. In case you want to destroy the resources, run the following command
```bash
terraform destroy
```

## Support

For issues please contact: akiva.ashkenazi@comm-it.cloud

<!-- terraform-docs output will go here -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_google"></a> [google](#requirement\_google) | 4.84.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | 2.4.2 |
| <a name="provider_google"></a> [google](#provider\_google) | 4.84.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.1 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_function"></a> [function](#module\_function) | GoogleCloudPlatform/cloud-functions/google | n/a |
| <a name="module_function_bucket"></a> [function\_bucket](#module\_function\_bucket) | terraform-google-modules/cloud-storage/google//modules/simple_bucket | n/a |
| <a name="module_function_sa"></a> [function\_sa](#module\_function\_sa) | terraform-google-modules/service-accounts/google | n/a |

## Resources

| Name | Type |
|------|------|
| [google_bigquery_table_iam_member.dataset_table_user](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/bigquery_table_iam_member) | resource |
| [google_billing_account_iam_member.billing_costs_manager](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/billing_account_iam_member) | resource |
| [google_billing_account_iam_member.billing_viewer](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/billing_account_iam_member) | resource |
| [google_cloud_scheduler_job.cloud_run_trigger](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/cloud_scheduler_job) | resource |
| [google_monitoring_notification_channel.email_channels](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/monitoring_notification_channel) | resource |
| [google_project_iam_member.daily_budget_cloud_scheduler_job_invoker_member](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/project_iam_member) | resource |
| [google_project_service.gcp_services](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/project_service) | resource |
| [google_service_account.daily_budget_cloud_scheduler_job_invoker](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/service_account) | resource |
| [google_storage_bucket_object.function_source](https://registry.terraform.io/providers/hashicorp/google/4.84.0/docs/resources/storage_bucket_object) | resource |
| [local_file.function_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.trigger_on_service_change](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [archive_file.function_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bigquery_dataset"></a> [bigquery\_dataset](#input\_bigquery\_dataset) | dataset in the billing export project where the billing data is held | `string` | n/a | yes |
| <a name="input_bigquery_dataset_table"></a> [bigquery\_dataset\_table](#input\_bigquery\_dataset\_table) | table in the dataset in the billing export project where the billing data is held | `string` | n/a | yes |
| <a name="input_billing_account_id"></a> [billing\_account\_id](#input\_billing\_account\_id) | id of the billing account on which to put a budget | `string` | n/a | yes |
| <a name="input_billing_account_services"></a> [billing\_account\_services](#input\_billing\_account\_services) | List of services for which to set up budgets on the entire billing account (for all projects). If general\_billing\_account\_alerts is not ON, this does nothing. | `list(list(string))` | n/a | yes |
| <a name="input_billing_data_export_project_id"></a> [billing\_data\_export\_project\_id](#input\_billing\_data\_export\_project\_id) | id of the project which has the billing export data for the desired billing account | `string` | n/a | yes |
| <a name="input_budget_ceiling"></a> [budget\_ceiling](#input\_budget\_ceiling) | Percent of daily average spend at which the customer should be concerned - for example, if the user is OK with spending in one day at most 20% over the daily average, this should be "1.20" | `string` | n/a | yes |
| <a name="input_budget_projects"></a> [budget\_projects](#input\_budget\_projects) | List of projects for which to set up budgets (without filtering by service). They must be connected to the billing account provided. The list may be empty. | `list(string)` | n/a | yes |
| <a name="input_emails"></a> [emails](#input\_emails) | List of email addresses for notification channels | `list(string)` | n/a | yes |
| <a name="input_function_bucket_name"></a> [function\_bucket\_name](#input\_function\_bucket\_name) | Name of the bucket in which to hold the function source code | `string` | n/a | yes |
| <a name="input_gcp_service_list"></a> [gcp\_service\_list](#input\_gcp\_service\_list) | The list of apis necessary for the project | `list(string)` | <pre>[<br>  "cloudresourcemanager.googleapis.com",<br>  "serviceusage.googleapis.com",<br>  "iam.googleapis.com",<br>  "run.googleapis.com",<br>  "cloudbuild.googleapis.com",<br>  "cloudscheduler.googleapis.com",<br>  "storage.googleapis.com",<br>  "cloudfunctions.googleapis.com",<br>  "bigquery.googleapis.com",<br>  "billingbudgets.googleapis.com",<br>  "discoveryengine.googleapis.com",<br>  "cloudbilling.googleapis.com"<br>]</pre> | no |
| <a name="input_general_billing_account_alerts"></a> [general\_billing\_account\_alerts](#input\_general\_billing\_account\_alerts) | Set to ON if want alerts on entire billing account, OFF otherwise | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | GCP region | `string` | n/a | yes |
| <a name="input_services_by_project"></a> [services\_by\_project](#input\_services\_by\_project) | A map where each key is a project and its value is a list of services, for setting budgets on service usage per project. | `map(list(list(string)))` | n/a | yes |
| <a name="input_threshold_percentages"></a> [threshold\_percentages](#input\_threshold\_percentages) | List of threshold percentages, formatted as strings. Ex 50% should be formatted as ".50" | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_function_uri"></a> [function\_uri](#output\_function\_uri) | The uri of the function. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->