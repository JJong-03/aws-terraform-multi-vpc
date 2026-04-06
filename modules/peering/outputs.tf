output "peering_id" {
  description = "VPC Peering Connection ID"
  value       = aws_vpc_peering_connection.mgmt_to_main.id
}
