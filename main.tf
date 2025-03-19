provider "aws" {
  region = "us-west-2"
}

data "aws_region" "current" {}


# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "FreeTierVPC"
  }
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"

  tags = {
    Name = "FreeTierPublicSubnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "FreeTierIGW"
  }
}

# Create a public route table with a default route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "FreeTierPublicRT"
  }
}

# Associate the subnet with the route table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create a security group allowing SSH and HTTP
resource "aws_security_group" "instance_sg" {
  name        = "FreeTierInstanceSG"
  description = "Allow SSH (22) and HTTP (80) access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FreeTierInstanceSG"
  }
}

# Create an EC2 instance with remote-exec user_data to install Python
resource "aws_instance" "web" {
  ami                    = "ami-0c94855ba95c71c99"  # Amazon Linux 2 AMI (free tier eligible for us-west-2)
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y python3
              EOF

  tags = {
    Name = "WordGuessAppInstance"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Create an S3 bucket with versioning enabled
resource "aws_s3_bucket" "assets" {
  bucket = "${var.bucket_prefix}-${var.environment}-${substr(data.aws_region.current.name, 0, 2)}"
  acl    = "private"

  tags = {
    Name = "WordGuessAppAssets"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags]
  }
}

resource "aws_s3_bucket_versioning" "assets_versioning" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}


# Outputs
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "s3_bucket_name" {
  description = "The S3 bucket name for the application assets"
  value       = aws_s3_bucket.assets.bucket
}
