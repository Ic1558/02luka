# Cloudflare DNS Configuration - theedges.work

**Last Updated:** 2025-12-04  
**Source:** Cloudflare Dashboard DNS Records

## DNS Records

| # | Type | Name | Content | Proxy Status | TTL |
|---|------|------|---------|--------------|-----|
| 1 | A | hooks.02luka.cloud | 192.168.1.43 | DNS only (reserved IP) | 2 min |
| 2 | CNAME | ai | edge-ipod-webapp.pages.dev | DNS only | Auto |
| 3 | CNAME | api-dashboard | api-dashboard.2cf1e9eb0dfd2477af7b0bea5bcc53d6.workers.dev | Proxied | Auto |
| 4 | CNAME | api-local | 2006a972-2181-4025-83c7-56f7e0174bff.cfargotunnel.com | Proxied | Auto |
| 5 | CNAME | api | 2006a972-2181-4025-83c7-56f7e0174bff.cfargotunnel.com | Proxied | Auto |
| 6 | CNAME | archive | cf7d221f-fa1b-4dcf-aacf-1b119dd763b0.cfargotunnel.com | Proxied | Auto |
| 7 | CNAME | control | cf7d221f-fa1b-4dcf-aacf-1b119dd763b0.cfargotunnel.com | Proxied | Auto |
| 8 | CNAME | gc | 4ecb776e-d3eb-46cd-9be6-2d1726fafb57.cfargotunnel.com | Proxied | Auto |
| 9 | CNAME | grafana | cf7d221f-fa1b-4dcf-aacf-1b119dd763b0.cfargotunnel.com | Proxied | Auto |
| 10 | CNAME | mobile | edge-ipod-webapp.pages.dev | Proxied | Auto |
| 11 | CNAME | monitoring | cf7d221f-fa1b-4dcf-aacf-1b119dd763b0.cfargotunnel.com | Proxied | Auto |
| 12 | CNAME | monitor | cf7d221f-fa1b-4dcf-aacf-1b119dd763b0.cfargotunnel.com | Proxied | Auto |
| 13 | CNAME | n8n | 8c87acc7-e77b-4487-a3fa-8f851005b96c.cfargotunnel.com | Proxied | Auto |
| 14 | CNAME | **ops** | **8c87acc7-e77b-4487-a3fa-8f851005b96c.cfargotunnel.com** | **Proxied** ✓ | **Auto** |
| 15 | CNAME | search | cf7d221f-fa1b-4dcf-aacf-1b119dd763b0.cfargotunnel.com | Proxied | Auto |
| 16 | CNAME | system | cf7d221f-fa1b-4dcf-aacf-1b119dd763b0.cfargotunnel.com | Proxied | Auto |
| 17 | CNAME | theedges.work | edges-adaptive-main.pages.dev | Proxied | Auto |
| 18 | CNAME | vlm2 | 4ecb776e-d3eb-46cd-9be6-2d1726fafb57.cfargotunnel.com | Proxied | Auto |
| 19 | CNAME | vlm | 8c87acc7-e77b-4487-a3fa-8f851005b96c.cfargotunnel.com | Proxied | Auto |
| 20 | CNAME | www.hooks.02luka.cloud | hooks.02luka.cloud | DNS only | 2 min |
| 21 | CNAME | www | edges-adaptive-main.pages.dev | Proxied | Auto |
| 22 | MX | theedges.work | route3.mx.cloudflare.net | DNS only | Auto |
| 23 | MX | theedges.work | route2.mx.cloudflare.net | DNS only | Auto |
| 24 | MX | theedges.work | route1.mx.cloudflare.net | DNS only | Auto |
| 25 | TXT | cf2024-1._domainkey | v=DKIM1 (RSA key) | DNS only | Auto |
| 26 | TXT | _dmarc | v=DMARC1; p=reject; sp=reject; adkim=s; aspf=s; | DNS only | Auto |
| 27 | TXT | *._domainkey | v=DKIM1; p= | DNS only | Auto |
| 28 | TXT | theedges.work | v=spf1 include:_spf.mx.cloudflare.net ~all | DNS only | Auto |
| 29 | Worker | dashboard.theedges.work | dashboard | Proxied | Auto |

## Summary

- **Total Records:** 29
- **Proxied (🟧):** 18 records
- **DNS Only:** 11 records
- **Tunnel-backed services:** ops, n8n, vlm (8c87acc7-e77b-4487-a3fa-8f851005b96c tunnel)
- **DNS Setup:** Full

## Tunnel Mappings

### Tunnel ID: `8c87acc7-e77b-4487-a3fa-8f851005b96c` (dashboard tunnel)
- **ops.theedges.work** → Health server (port 4000) with X-Relay-Key authentication
- **n8n.theedges.work** → n8n workflow automation (port 5678)
- **vlm.theedges.work** → VLM service

### Tunnel ID: `2006a972-2181-4025-83c7-56f7e0174bff` (api tunnel)
- **api.theedges.work** → API service
- **api-local.theedges.work** → Local API service

### Tunnel ID: `cf7d221f-fa1b-4dcf-aacf-1b119dd763b0` (monitoring tunnel)
- **archive.theedges.work**
- **control.theedges.work**
- **grafana.theedges.work**
- **monitoring.theedges.work**
- **monitor.theedges.work**
- **search.theedges.work**
- **system.theedges.work**

### Tunnel ID: `4ecb776e-d3eb-46cd-9be6-2d1726fafb57` (gc/vlm2 tunnel)
- **gc.theedges.work**
- **vlm2.theedges.work**

## Notes

- Record #14 (**ops**) is configured as CNAME → Proxied with correct tunnel ID endpoint for the health_server relay key validation.
- All tunnel endpoints use Cloudflare's automatic TTL.
- Email routing uses Cloudflare MX records (route1-3.mx.cloudflare.net).
- SPF, DKIM, and DMARC records are configured for email security.

## Related Configuration Files

- Tunnel config: `~/.cloudflared/dashboard.yml` (for ops/n8n/vlm tunnel)
- Health server: `~/02luka/misc/health_server.cjs`
- LaunchAgent: `~/Library/LaunchAgents/com.02luka.cloudflared.dashboard.plist`
- Tunnel script: `~/02luka/tools/cloudflared_dashboard_tunnel.zsh`
- Transform Rule: See `g/docs/cloudflare_transform_rule_ops.md` for X-Relay-Key header configuration

## Dashboard Link

[Cloudflare DNS Dashboard](https://dash.cloudflare.com/2cf1e9eb0dfd2477af7b0bea5bcc53d6/theedges.work/dns/records)
