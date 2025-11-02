output "backup_vault_arn" {
  value       = aws_backup_vault.primary.arn
  description = "ARN of the primary backup vault."
}

output "backup_plan_id" {
  value       = aws_backup_plan.this.id
  description = "Backup plan ID."
}

output "replica_vault_arns" {
  value       = { for r, v in aws_backup_vault.replicas : r => v.arn }
  description = "Replica vault ARNs (if any)."
}
