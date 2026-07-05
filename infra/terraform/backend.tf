terraform {
  backend "s3" {
    bucket         = "phoenix-tfstate-joshua-2026"
    key            = "phoenix/main/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "phoenix-tf-locks"
    encrypt        = true
  }
}
