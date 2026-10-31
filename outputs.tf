output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.secops.id
}

output "tunnel_token" {
  value     = data.cloudflare_zero_trust_tunnel_cloudflared_token.secops.token
  sensitive = true
}
