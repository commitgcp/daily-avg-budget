terraform {
  backend "gcs" {
    #Replace this with your state bucket
    bucket = "BUCKET-NAME-GOES-HERE"
    prefix = "terraform/state"
  }
}