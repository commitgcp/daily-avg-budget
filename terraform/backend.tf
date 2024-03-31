terraform {
  backend "gcs" {
    #Replace this with your state bucket
    bucket = "tf-state-budget-automation"
    prefix = "terraform/state"
  }
}