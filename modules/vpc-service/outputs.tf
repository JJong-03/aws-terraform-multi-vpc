output "vpc_id" {
  value = aws_vpc.this.id
}

output "subnet_service_public_id" {
  value = aws_subnet.service_public.id
}

output "subnet_service_private_id" {
  description = "ECS/Fargate Task가 배치될 Private Subnet ID"
  value       = aws_subnet.service_private.id
}
