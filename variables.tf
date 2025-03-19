
variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "wordguess"
}

variable "environment" {
  description = "Deployment environment (e.g., dev or prod)"
  type        = string
  default     = "dev"
}