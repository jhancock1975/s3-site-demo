terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "site_cname" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain
  type    = "CNAME"
  value   = aws_s3_bucket.static_site.website_endpoint
  proxied = true
}

resource "cloudflare_page_rule" "cache_everything" {
  zone_id = var.cloudflare_zone_id
  target  = "https://${var.domain}/*"

  actions  {
    cache_level     = "cache_everything"
    edge_cache_ttl  = 7200
  }
}
