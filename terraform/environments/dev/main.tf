
module "aws" {
  source = "../../modules/aws"

  aws_region  = var.aws_region
  bucket_name = var.bucket_name
}
