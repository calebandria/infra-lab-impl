provider "aws" {
  region = "us-east-1"
}
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_key_pair" "admin" {
  key_name   = "admin"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.admin.key_name
}

resource "aws_iam_role" "ec2" {
  name = "ec2-ssm-reader"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_ssm" {
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = "arn:aws:ssm:*:*:parameter/app/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-ssm-reader"
  role = aws_iam_role.ec2.name
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "trail" {
  bucket = "infralab-cloudtrail-${data.aws_caller_identity.current.account_id}"
}

resource "aws_cloudtrail" "main" {
  name                          = "infralab-trail"
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
}