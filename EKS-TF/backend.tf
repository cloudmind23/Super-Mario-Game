terraform {
  backend "s3" {
    bucket = "YOUR_S3_BUCKET_NAME"
    key    = "EKS/terraform.tfstate"
    region = "us-east-1"
  }
}
