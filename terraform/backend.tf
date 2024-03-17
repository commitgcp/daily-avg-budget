terraform {
  backend "gcs" {
    #Replace this with terraform output during setup
    bucket = "wiliot-billing-alerts-tf"
    prefix = "terraform/state"
  }
}