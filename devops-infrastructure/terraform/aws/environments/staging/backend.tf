# Uncomment and configure when ready to use remote state
terraform {
  backend "s3" {
    bucket  = "terraform-devsecops-state-bucket"
    key     = "devsecops/staging/terraform.tfstate"
    region  = "eu-south-2"
    profile = "deifzar"
    encrypt = true
    # dynamodb_table = "terraform-state-lock" # Optional: for state locking. DynamoDB-based locking is deprecated and will be removed in a future minor version
    use_lockfile = true # Enabling S3 State Locking
  }
}
