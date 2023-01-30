terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8"
    }
  }
}

provider "aws" {
  # Choose the region where you want the S3 bucket to be hosted
  region  = "us-east-1"
}

# To avoid repeatedly specifying the path, we'll declare it as a variable
variable "website_root" {
  type        = string
  description = "Path to the root of website content"
  default     = "./site"
}

resource "aws_s3_bucket" "deviget-test-project" {
  bucket = "deviget.caminosdepapel.com.ar"

  tags = {
    Name        = "Deviget Test Project"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_acl" "deviget-test-project" {
  bucket = aws_s3_bucket.deviget-test-project.id
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "deviget-test-project" {
  bucket = aws_s3_bucket.deviget-test-project.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# To print the bucket's website URL after creation
output "website_endpoint" {
  value = aws_s3_bucket.deviget-test-project.website_endpoint
}

resource "aws_s3_object" "index" {
  bucket = "deviget.caminosdepapel.com.ar"
  key    = "index.html"
  source = "./site/index.html"
  content_type = "text/html"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("./site/index.html")
}

resource "aws_s3_object" "styles" {
  bucket = "deviget.caminosdepapel.com.ar"
  key    = "styles.css"
  source = "./site/styles.css"
  content_type = "text/css"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("./site/styles.css")
}

data "archive_file" "site-folder"{
  type = "zip"

  source_dir  = "${path.module}/site"
  output_path = "${path.module}/temp/backup.zip"
}

resource "aws_s3_bucket_acl" "deviget-test-project-acl" {
  bucket = aws_s3_bucket.deviget-test-project.id
  acl    = "public-read"
}

# create bucket policy
resource "aws_s3_bucket_policy" "deviget-test-project-policy" {
  bucket = aws_s3_bucket.deviget-test-project.id

  policy = <<POLICY
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Principal": "*",
              "Action": "s3:GetObject",
              "Resource": "${aws_s3_bucket.deviget-test-project.arn}/*"
          }
      ]
  }
  POLICY
}

variable "mime_types" {
  default = {
    htm   = "text/html"
    html  = "text/html"
    css   = "text/css"
    js    = "application/javascript"
    map   = "application/javascript"
    json  = "application/json"
    png   = "image/png"
    jpg   = "image/jpg"
    jpeg  = "image/jpg"
    gif   = "image/gif"
    svg   = "image/svg+xml"
  }
}

locals {
  s3_origin_id = "deviget.caminosdepapel.com.ar/index.html"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "deviget.caminosdepapel.com.ar/index.html"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.deviget-test-project.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Deviget Test Project"
  default_root_object = "index.html"

  # Configure logging here if required 	
  #logging_config {
  #  include_cookies = false
  #  bucket          = "mylogs.s3.amazonaws.com"
  #  prefix          = "myprefix"
  #}

  # If you have domain configured use it here 
  # aliases = ["mywebsite.example.com", "s3-static-web-dev.example.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "IN", "IR"]
    }
  }

  tags = {
    Environment = "Dev"
    Name        = "Deviget Test Project"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# to get the Cloud front URL if doamin/alias is not configured
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

resource "aws_route53_zone" "deviget-test-project" {
#  provider = "aws.prod"
  name = "deviget.caminosdepapel.com.ar"
}

resource "aws_route53_record" "origin" {
#  provider = "aws.prod"
  zone_id = "${aws_route53_zone.deviget-test-project.zone_id}"
  name = "deviget.caminosdepapel.com.ar"
  type = "A"

  alias {
    name = "${aws_s3_bucket.deviget-test-project.website_domain}"
    zone_id = "${aws_s3_bucket.deviget-test-project.hosted_zone_id}"
    evaluate_target_health = false
  }
}