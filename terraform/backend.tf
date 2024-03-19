terraform {
  backend "gcs" {
    #Replace this with terraform output during setup
    bucket = "BUCKET NAME GOES HERE"
    prefix = "terraform/state"
  }
}