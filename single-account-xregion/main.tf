provider "aws" {
  region = "eu-central-1" # Frankfurt (source)
}

provider "aws" {
  alias  = "eu-west-1"    # Ireland (replica)
  region = "eu-west-1"
}

module "backup" {
  source = "../../modules/aws-backup"

  name = "prod"
  tags = { Environment = "prod", Owner = "owner@eulerhermes.com" }

  selection_tags = [
    { key = "ToBackup", type = "STRINGEQUALS", value = "true" },
    { key = "Owner",    type = "STRINGEQUALS", value = "owner@eulerhermes.com" }
  ]

  create_replica_vaults = true
  replica_regions       = ["eu-west-1"]

  providers = {
    aws.eu-west-1 = aws.eu-west-1
  }

  plan_rules = [
    {
      name              = "daily-35d"
      schedule_cron     = "cron(0 2 ? * * *)"
      start_window      = 60
      completion_window = 180
      lifecycle = {
        delete_after_days       = 35
        cold_storage_after_days = 7
      }
      copy_to = [
        { destination_vault_arn = module.backup.replica_vault_arns["eu-west-1"] }
      ]
    }
  ]
}
