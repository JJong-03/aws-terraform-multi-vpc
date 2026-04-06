output "sg_alb_id" {
  description = "ALB Security Group ID"
  value       = aws_security_group.alb.id
}

output "sg_web_id" {
  description = "EC2 Nginx Security Group ID"
  value       = aws_security_group.web.id
}

output "sg_eks_node_id" {
  description = "EKS Node Security Group ID"
  value       = aws_security_group.eks_node.id
}

output "sg_db_id" {
  description = "Aurora MySQL Security Group ID"
  value       = aws_security_group.db.id
}

output "sg_openvpn_id" {
  description = "OpenVPN EC2 Security Group ID"
  value       = aws_security_group.openvpn.id
}

output "sg_ecs_id" {
  description = "ECS Fargate Task Security Group ID"
  value       = aws_security_group.ecs.id
}
