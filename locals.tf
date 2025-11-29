locals {
  common_tags = {
    project     = var.project_name
    environment = var.ENV
    managed_by  = "terraform"
  }
}
