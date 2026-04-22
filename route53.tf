locals {
  route53_zone_name_normalized = trimsuffix(trimspace(var.route53_zone_name), ".")
}

data "aws_route53_zone" "existing_by_id" {
  count = !var.route53_create_hosted_zone && var.route53_zone_id != "" ? 1 : 0

  zone_id      = var.route53_zone_id
  private_zone = false
}

data "aws_route53_zone" "existing_by_name" {
  count = !var.route53_create_hosted_zone && var.route53_zone_id == "" && local.route53_zone_name_normalized != "" ? 1 : 0

  name         = "${local.route53_zone_name_normalized}."
  private_zone = false
}

resource "aws_route53_zone" "public" {
  count = var.route53_create_hosted_zone ? 1 : 0

  name          = local.route53_zone_name_normalized
  force_destroy = var.route53_force_destroy

  lifecycle {
    precondition {
      condition     = local.route53_zone_name_normalized != ""
      error_message = "route53_zone_name must be set when route53_create_hosted_zone is true."
    }
  }
}

locals {
  route53_zone_id_selected = var.route53_create_hosted_zone ? aws_route53_zone.public[0].zone_id : (
    var.route53_zone_id != "" ? data.aws_route53_zone.existing_by_id[0].zone_id : (
      local.route53_zone_name_normalized != "" ? data.aws_route53_zone.existing_by_name[0].zone_id : null
    )
  )

  route53_zone_arn_selected = var.route53_create_hosted_zone ? aws_route53_zone.public[0].arn : (
    var.route53_zone_id != "" ? data.aws_route53_zone.existing_by_id[0].arn : (
      local.route53_zone_name_normalized != "" ? data.aws_route53_zone.existing_by_name[0].arn : null
    )
  )

  route53_zone_name_selected = var.route53_create_hosted_zone ? aws_route53_zone.public[0].name : (
    var.route53_zone_id != "" ? data.aws_route53_zone.existing_by_id[0].name : (
      local.route53_zone_name_normalized != "" ? data.aws_route53_zone.existing_by_name[0].name : null
    )
  )

  route53_name_servers_selected = var.route53_create_hosted_zone ? aws_route53_zone.public[0].name_servers : (
    var.route53_zone_id != "" ? data.aws_route53_zone.existing_by_id[0].name_servers : (
      local.route53_zone_name_normalized != "" ? data.aws_route53_zone.existing_by_name[0].name_servers : []
    )
  )
}
