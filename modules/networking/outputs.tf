# ============================================
# Networking Module Outputs
# ============================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets"
  value       = aws_subnet.private[*].cidr_block
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "security_group_id" {
  description = "ID of the main security group"
  value       = aws_security_group.main.id
}

output "security_group_arn" {
  description = "ARN of the main security group"
  value       = aws_security_group.main.arn
}

output "bastion_security_group_id" {
  description = "ID of the bastion security group"
  value       = var.enable_bastion ? aws_security_group.bastion[0].id : null
}

output "bastion_instance_id" {
  description = "ID of the bastion instance"
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
}

output "bastion_public_ip" {
  description = "Public IP of the bastion instance"
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
}

output "flow_log_id" {
  description = "ID of the VPC flow log"
  value       = var.enable_vpc_flow_logs ? aws_flow_log.main[0].id : null
}

output "flow_log_group_name" {
  description = "Name of the CloudWatch log group for flow logs"
  value       = var.enable_vpc_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].name : null
}