resource "azurerm_storage_share" "hashistack_job_filesystem" {
  name                 = "hashistack-jobs-filesystem"
  storage_account_name = data.azurerm_storage_account.hashistack_job.name
  quota                = 100 #GB
}