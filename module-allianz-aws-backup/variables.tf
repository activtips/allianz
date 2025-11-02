variable "name" {
  description = "Logical name prefix for the backup plan and vault."
  type        = string
}

variable "tags" {
  description = "Standard tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN for vault encryption. If null, AWS-managed key is used."
  type        = string
  default     = null
}

variable "enable_vault_lock" {
  description = "Enable Vault Lock (WORM) protection."
  type        = bool
  default     = true
}

variable "vault_lock" {
  description = "WORM Vault Lock settings (days)."
  type = object({
    min_retention_days     = number
    max_retention_days     = number
    changeable_for_days    = optional(number)
  })
  default = {
    min_retention_days = 35
    max_retention_days = 3650
  }
  validation {
    condition     = var.vault_lock.min_retention_days > 0 && var.vault_lock.max_retention_days >= var.vault_lock.min_retention_days
    error_message = "max_retention_days must be >= min_retention_days and > 0."
  }
}

variable "selection_tags" {
  description = "Tags used for selecting resources to back up. Example: [{key=\"ToBackup\", type=\"STRINGEQUALS\", value=\"true\"}, {key=\"Owner\", type=\"STRINGEQUALS\", value=\"owner@eulerhermes.com\"}]"
  type = list(object({
    key   = string
    type  = string
    value = string
  }))
}

variable "plan_rules" {
  description = <<EOT
Backup plan rules:
- schedule_cron: AWS Backup cron (e.g., cron(0 5 ? * * *))
- lifecycle: delete_after_days, cold_storage_after_days
- copy_to: destination vault ARNs (cross-region or cross-account)
- recovery_point_tags: optional metadata tags
EOT
  type = list(object({
    name                     = string
    schedule_cron            = string
    start_window             = number
    completion_window        = number
    enable_continuous_backup = optional(bool, false)
    lifecycle = object({
      delete_after_days        = number
      cold_storage_after_days  = optional(number)
    })
    copy_to = optional(list(object({
      destination_vault_arn = string
      iam_role_arn          = optional(string)
      lifecycle_override = optional(object({
        delete_after_days        = number
        cold_storage_after_days  = optional(number)
      }))
    })), [])
    recovery_point_tags = optional(map(string), {})
  }))
}

variable "create_replica_vaults" {
  description = "Automatically create replica vaults in other regions (same account)."
  type        = bool
  default     = false
}

variable "replica_regions" {
  description = "List of regions where replica vaults will be created (requires aliased providers)."
  type        = list(string)
  default     = []
}

variable "replica_vault_suffix" {
  description = "Suffix appended to replica vault names."
  type        = string
  default     = "dr"
}
