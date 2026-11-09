provider "aws" {
  region              = "us-east-2"
  profile             = "attendance-lab"
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project    = "attendance"
      Deployment = var.deployment_name
      ManagedBy  = "Terraform"
      Purpose    = "ansible-class-lab"
    }
  }
}
