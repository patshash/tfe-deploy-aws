provider "aws" {
  region = "ap-southeast-2"

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Example   = "tfe-fdo-complete"
    }
  }
}
