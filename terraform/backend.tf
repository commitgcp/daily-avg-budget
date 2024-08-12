terraform {
  backend "gcs" {
    #Replace this with your state bucket
    bucket = "BUCKET-NAME-HERE"
    prefix = "terraform/state"
  }
}