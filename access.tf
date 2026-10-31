resource "cloudflare_zero_trust_access_policy" "admin_only" {
  account_id = var.account_id
  name       = "admin-only-email"
  decision   = "allow"

  include = [
    { email = { email = var.admin_email } }
  ]
}

resource "cloudflare_zero_trust_access_application" "admin" {
  account_id       = var.account_id
  name             = "SecOps Admin Console"
  domain           = "admin.${var.domain}"
  type             = "self_hosted"
  session_duration = "1h"

  policies = [
    { id = cloudflare_zero_trust_access_policy.admin_only.id, precedence = 1 }
  ]
}
