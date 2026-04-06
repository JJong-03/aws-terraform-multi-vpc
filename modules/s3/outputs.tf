output "bucket_id" {
  description = "S3 버킷 이름 (cloudfront 모듈에서 bucket policy 생성 시 사용)"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "S3 버킷 ARN"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "S3 버킷 리전 도메인 (CloudFront S3 Origin 주소)"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
