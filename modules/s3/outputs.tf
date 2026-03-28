output "bucket_name" {
  description = "Name of the S3 bucket for book file storage."
  value       = aws_s3_bucket.books.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.books.arn
}

output "bucket_domain_name" {
  description = "Regional domain name of the S3 bucket."
  value       = aws_s3_bucket.books.bucket_regional_domain_name
}
