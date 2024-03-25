terraform {
  backend "gcs" {
    #Replace this with your state bucket
    bucket = ""
    prefix = "terraform/state"
  }
}