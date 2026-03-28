locals {
  bucket_name = "${var.project_name}-${var.environment}-books-${var.bucket_suffix}"
}

resource "aws_s3_bucket" "books" {
  bucket = local.bucket_name

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "books" {
  bucket = aws_s3_bucket.books.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
