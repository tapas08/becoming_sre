output "cluster_role_arn" {
  value = aws_iam_role.cluster_role.arn
}

output "node_role_arn" {
  value = aws_iam_role.node_role.arn
}

output "vpc_id" {
  value = aws_vpc.staging_vpc.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.staging_subnet_public_01.id,
    aws_subnet.staging_subnet_public_02.id
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.staging_subnet_private_01.id,
    aws_subnet.staging_subnet_private_02.id
  ]
}

output "db_subnet_ids" {
  value = [
    aws_subnet.staging_subnet_db_01.id
  ]
}