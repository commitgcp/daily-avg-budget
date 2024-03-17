terraform {
  backend "gcs" {
    #Replace this with terraform output during setup
    bucket = "tf-state-budget-automation"
    prefix = ""
  }
}