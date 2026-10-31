resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "secops" {
  account_id    = var.account_id
  name          = "secops-tunnel-iac"
  config_src    = "cloudflare" # configuração gerida remotamente (pelo Terraform)
  tunnel_secret = random_id.tunnel_secret.b64_std
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "secops" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.secops.id

  config = {
    ingress = [
      { hostname = "tunnel.${var.domain}", service = "http://127.0.0.1:80" },
      { hostname = "admin.${var.domain}", service = "http://127.0.0.1:8080" },
      { service = "http_status:404" } # catch-all obrigatório
    ]
  }
}

locals {
  hostnames = toset(["tunnel", "admin"])
}

resource "cloudflare_dns_record" "app" {
  for_each = local.hostnames

  zone_id = var.zone_id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.secops.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # 1 = automático
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "secops" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.secops.id
}
