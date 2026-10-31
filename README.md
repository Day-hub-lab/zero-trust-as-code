# Zero Trust as Code

A defence-in-depth setup for a self-hosted admin endpoint, built entirely with Terraform on Cloudflare's free tier: **edge WAF**, **identity-aware access (ZTNA)** and an **outbound-only tunnel** with zero inbound ports on the origin.

![ci](https://github.com/Day-hub-lab/zero-trust-as-code/actions/workflows/ci.yml/badge.svg)

I first built this lab by hand (WAF + tunnel + Access). This repository is the same architecture rebuilt as code: reproducible, reviewable and checked by a security pipeline on every change.

## Architecture

```text
 Client / browser / attacker
            |
            v
 +--------------------------------------------------------------+
 | Layer 1 - Edge WAF (Cloudflare)                              |
 |  Custom rule blocks requests to the admin host that lack     |
 |  the Sec-CH-UA client hint (HTTP 403)                        |
 +----------------------------+---------------------------------+
                              |
                              v
 +--------------------------------------------------------------+
 | Layer 2 - Identity-aware proxy (Cloudflare Access)           |
 |  Unauthenticated requests are redirected (302) to login.     |
 |  Policy: allow a single e-mail via one-time PIN (OTP),       |
 |  1 hour session, HttpOnly cookie                             |
 +----------------------------+---------------------------------+
                              |
                              v
 +--------------------------------------------------------------+
 | Layer 3 - Origin hardening + outbound tunnel                 |
 |  No inbound ports open. cloudflared dials out (QUIC/TLS).    |
 |  nginx listens on 127.0.0.1 only.                            |
 +--------------------------------------------------------------+
```

## What Terraform manages

| File | Resources |
|---|---|
| `tunnel.tf` | Cloudflare Tunnel (remotely managed), ingress rules (with the mandatory catch-all), proxied CNAME records, tunnel token |
| `access.tf` | Reusable Access policy and the self-hosted Access application |
| `waf.tf` | Custom WAF ruleset (`http_request_firewall_custom` phase) |
| `providers.tf` / `variables.tf` / `outputs.tf` | Provider pinning, inputs, outputs (token marked `sensitive`) |

## Repository checks

- **Pre-commit (local):** `terraform fmt`, `terraform validate`, `gitleaks`
- **GitHub Actions (`ci.yml`):** `fmt -check`, `init -backend=false` + `validate`, `tflint`, `checkov`, `gitleaks` (full history)
- **Drift detection:** `drift-check.sh` runs `terraform plan -detailed-exitcode` and reports whether the real infrastructure still matches the code

The CI needs **no secrets**: it never talks to Cloudflare.

### Screenshots

| CI catching a badly formatted file | CI passing |
|---|---|
| ![ci-fail](docs/img/ci-fail.png) | ![ci-pass](docs/img/ci-pass.png) |

## Reproduce it

**Prerequisites:** a Cloudflare account with a domain, Terraform >= 1.6, and a server (or WSL) to run the origin.

1. Create a scoped API token with: Account - Cloudflare Tunnel: Edit; Account - Access: Apps and Policies: Edit; Zone - DNS: Edit; Zone - Zone WAF: Edit; Zone - Zone: Read.
2. Configure inputs:
   ```bash
   cp terraform.tfvars.example terraform.tfvars   # fill in your own values
   export CLOUDFLARE_API_TOKEN='...'
   ```
3. Apply:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```
4. On the origin, run nginx on `127.0.0.1` and start the tunnel with the token:
   ```bash
   terraform output -raw tunnel_token   # keep it out of Git and shell history
   TUNNEL_TOKEN='<token>' cloudflared tunnel --no-autoupdate run
   ```
5. Verify the layers:
   ```bash
   curl -sI https://admin.example.com | head -n1                 # 403 (WAF)
   curl -sI -H 'sec-ch-ua: "Chromium";v="130"' \
        https://admin.example.com | grep -iE '^HTTP|^location'   # 302 to Access login
   ```

## Security decisions

- **Least privilege:** a scoped API token instead of the global key.
- **No secrets in Git:** `*.tfvars`, `*.tfstate`, plans and backend files are ignored; the tunnel token is a `sensitive` output; `gitleaks` runs locally and in CI.
- **No inbound exposure:** the origin only makes outbound connections, so its real IP is not reachable from scanners.
- **Short sessions:** Access sessions last one hour and the session cookie is HttpOnly.
- **Everything reviewable:** infrastructure changes go through code, and formatting/validation/lint/security checks run on every push and pull request.

## Limitations (on purpose, stated honestly)

- **The `Sec-CH-UA` rule is noise reduction, not a security control.** Any attacker can forge the header, and Firefox and Safari do not send it, so they get blocked too. The real access control is Layer 2.
- **State is local.** No remote backend, to keep the project free and card-free. Consequently there is no state locking and the CI does not run `plan`/`apply`; those run from my machine.
- **Drift detection is a local script,** not a scheduled pipeline, for the same reason.
- **Checkov has limited coverage for the Cloudflare provider,** so the scan mostly proves the pipeline works rather than finding many issues.
- **The origin only runs while my machine is on,** which is fine for a lab.

## Lessons learned

- Existing resources must be brought under management with `terraform import`, and the ID format differs per resource (for example `accounts/<account_id>/<app_id>` for Access applications).
- A zone has a single custom-rules ruleset per phase; managing it with Terraform can replace rules created by hand, so import it first.
- Tunnel ingress must end with a catch-all rule.
- A tunnel configuration can drift silently if an old local connector keeps running next to the new one.

## Next

- Refactor into modules (`tunnel`, `access`, `waf`)
- Remote state and a scheduled drift workflow
- Policy as code (OPA/Conftest) to block plans that violate security rules
- The same pattern on AWS (VPC, IAM, GuardDuty)
