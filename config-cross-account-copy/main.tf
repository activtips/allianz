provider "aws" {
  alias  = "source"
  region = "eu-central-1"
}

provider "aws" {
  alias  = "backupacct"
  region = "eu-central-1"
}

resource "aws_backup_vault" "dest_vault" {
  provider = aws.backupacct
  name     = "backupacct-vault"
  tags     = { Environment = "backup", ManagedBy = "Terraform" }
}

module "backup_source" {
  source     = "../../modules/aws-backup"
  providers  = { aws = aws.source }
  name       = "prod"
  tags       = { Environment = "prod" }
  selection_tags = [{ key = "ToBackup", type = "STRINGEQUALS", value = "true" }]

  plan_rules = [
    {
      name              = "daily-cross-account"
      schedule_cron     = "cron(0 1 ? * * *)"
      start_window      = 60
      completion_window = 180
      lifecycle = {
        delete_after_days = 35
      }
      copy_to = [
        { destination_vault_arn = aws_backup_vault.dest_vault.arn }
      ]
    }
  ]
}
