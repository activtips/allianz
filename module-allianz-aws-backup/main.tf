locals {
  name_sanitized = replace(lower(var.name), "/[^a-z0-9-]/", "-")
  standard_tags  = merge({ "ManagedBy" = "Terraform", "Module" = "aws-backup" }, var.tags)
}

# --- Primary Vault ---
resource "aws_backup_vault" "primary" {
  name        = "${local.name_sanitized}-vault"
  kms_key_arn = var.kms_key_arn
  tags        = local.standard_tags
}

# --- WORM / Vault Lock ---
resource "aws_backup_vault_lock_configuration" "this" {
  count               = var.enable_vault_lock ? 1 : 0
  backup_vault_name   = aws_backup_vault.primary.name
  min_retention_days  = var.vault_lock.min_retention_days
  max_retention_days  = var.vault_lock.max_retention_days
  changeable_for_days = try(var.vault_lock.changeable_for_days, null)
}

# --- Optional replica vaults (cross-region, same account) ---
resource "aws_backup_vault" "replicas" {
  for_each = var.create_replica_vaults ? toset(var.replica_regions) : []
  provider = aws.each.value
  name     = "${local.name_sanitized}-${var.replica_vault_suffix}-${each.value}"
  tags     = local.standard_tags
}

# --- IAM role for AWS Backup service ---
data "aws_iam_policy_document" "backup_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "${local.name_sanitized}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume.json
  tags               = local.standard_tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# --- Backup Plan ---
resource "aws_backup_plan" "this" {
  name = "${local.name_sanitized}-plan"
  tags = local.standard_tags

  dynamic "rule" {
    for_each = var.plan_rules
    content {
      rule_name                = rule.value.name
      target_vault_name        = aws_backup_vault.primary.name
      schedule                 = rule.value.schedule_cron
      start_window             = rule.value.start_window
      completion_window        = rule.value.completion_window
      enable_continuous_backup = try(rule.value.enable_continuous_backup, false)
      recovery_point_tags      = try(rule.value.recovery_point_tags, {})

      lifecycle {
        delete_after       = rule.value.lifecycle.delete_after_days
        cold_storage_after = try(rule.value.lifecycle.cold_storage_after_days, null)
      }

      dynamic "copy_action" {
        for_each = try(rule.value.copy_to, [])
        content {
          destination_vault_arn = copy_action.value.destination_vault_arn
          lifecycle {
            delete_after       = try(copy_action.value.lifecycle_override.delete_after_days, rule.value.lifecycle.delete_after_days)
            cold_storage_after = try(copy_action.value.lifecycle_override.cold_storage_after_days, rule.value.lifecycle.cold_storage_after_days, null)
          }
        }
      }
    }
  }
}

# --- Resource Selection ---
resource "aws_backup_selection" "by_tags" {
  name         = "${local.name_sanitized}-selection"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.this.id

  dynamic "selection_tag" {
    for_each = var.selection_tags
    content {
      key   = selection_tag.value.key
      type  = selection_tag.value.type
      value = selection_tag.value.value
    }
  }
}
