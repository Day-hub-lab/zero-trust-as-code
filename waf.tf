resource "cloudflare_ruleset" "custom_waf" {
  zone_id = var.zone_id
  name    = "custom-waf"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [
    {
      action      = "block"
      description = "Bloquear pedidos ao admin sem Sec-CH-UA"
      enabled     = true
      expression  = "(http.host eq \"admin.${var.domain}\" and not any(http.request.headers.names[*] eq \"sec-ch-ua\"))"
    }
  ]
}
