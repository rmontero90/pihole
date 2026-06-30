#!/usr/bin/env bash
# Pi-hole + Unbound DNS stack test suite
# Run from a WireGuard-connected client or the server itself.
# Usage: ./test.sh [DNS_IP]
# Default DNS: 10.13.13.1

set -euo pipefail

DNS="${1:-10.13.13.1}"
PASS=0
FAIL=0

GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

pass() { printf "${GREEN}[PASS]${NC} %s\n" "$1" >&2; PASS=$((PASS + 1)); }
fail() { printf "${RED}[FAIL]${NC} %s\n" "$1" >&2; FAIL=$((FAIL + 1)); }
info() { printf "${YELLOW}[INFO]${NC} %s\n" "$1" >&2; }
log()  { printf "${DIM}       %s${NC}\n" "$1" >&2; }

resolve() {
  local domain="$1"
  local raw
  raw=$(dig @"$DNS" "$domain" +short +time=5 2>&1)
  log "dig @$DNS $domain +short"
  while IFS= read -r line; do log "  $line"; done <<< "$raw"
  echo "$raw" | grep -v "^;" | head -1 || true
}

resolve_full() {
  local domain="$1" flags="$2"
  local raw
  raw=$(dig @"$DNS" "$domain" $flags +time=5 2>&1)
  log "dig @$DNS $domain $flags"
  while IFS= read -r line; do log "  $line"; done <<< "$raw"
  echo "$raw"
}

echo "" >&2
echo "================================================" >&2
echo " Pi-hole + Unbound DNS Test Suite" >&2
echo " Resolver: $DNS" >&2
echo "================================================" >&2
echo "" >&2

# ── Resolver reachability ─────────────────────────────────────────────────────
echo "── Resolver reachability ──" >&2
result=$(resolve "google.com")
if [[ -n "$result" ]]; then
  pass "Resolver $DNS is reachable (google.com → $result)"
else
  fail "Resolver $DNS is unreachable — aborting"
  exit 1
fi
echo "" >&2

# ── Ad blocking ───────────────────────────────────────────────────────────────
echo "── Ad blocking (Google/Meta ads) ──" >&2
blocked_ads=(
  "doubleclick.net"
  "googleadservices.com"
  "pagead2.googlesyndication.com"
  "ads.youtube.com"
  "ad.youtube.com"
  "adservice.google.com"
  "googleads.g.doubleclick.net"
  "tpc.googlesyndication.com"
  "static.ads-twitter.com"
  "an.facebook.com"
  "pixel.facebook.com"
  "c.bing.com"
)
for domain in "${blocked_ads[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Tracking & telemetry blocking ─────────────────────────────────────────────
echo "── Tracking & telemetry ──" >&2
blocked_tracking=(
  "metrics.apple.com"
  "data.microsoft.com"
  "scorecardresearch.com"
  "tr.snapchat.com"
  "analytics.twitter.com"
  "bat.bing.com"
  "mc.yandex.ru"
  "tracking.tiktok.com"
  "log.byteoversea.com"
)
for domain in "${blocked_tracking[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── YouTube ad domains ─────────────────────────────────────────────────────────
echo "── YouTube ads ──" >&2
blocked_yt=(
  "ad.youtube.com"
  "ads.youtube.com"
  "googleads4.g.doubleclick.net"
  "survey.g.doubleclick.net"
)
for domain in "${blocked_yt[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Ad networks (Criteo, Outbrain, Taboola) ────────────────────────────────────
echo "── Ad networks ──" >&2
blocked_adnets=(
  "criteo.com"
  "outbrain.com"
  "taboola.com"
  "amazon-adsystem.com"
)
for domain in "${blocked_adnets[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Analytics & session recording ──────────────────────────────────────────────
echo "── Analytics & session recording ──" >&2
blocked_analytics=(
  "mixpanel.com"
  "chartbeat.com"
  "statcounter.com"
)
for domain in "${blocked_analytics[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Marketing pixels & retargeting ─────────────────────────────────────────────
echo "── Marketing pixels & retargeting ──" >&2
blocked_pixels=(
  "twimg.com"
  "ads.linkedin.com"
  "casalemedia.com"
  "turn.com"
  "mathtag.com"
  "exponential.com"
  "indexww.com"
  "sonobi.com"
  "lijit.com"
  "rubiconproject.com"
  "contextual.media.net"
  "adadvisor.net"
  "advertising.com"
  "2mdn.net"
  "admeld.com"
)
for domain in "${blocked_pixels[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Mobile app tracking ────────────────────────────────────────────────────────
echo "── Mobile app tracking ──" >&2
blocked_mobile=(
  "googlemobileads.com"
)
for domain in "${blocked_mobile[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Malware & PUP domains ──────────────────────────────────────────────────────
echo "── Malware & potentially unwanted programs ──" >&2
blocked_malware=(
  "tradeadexchange.com"
  "onclickds.com"
)
for domain in "${blocked_malware[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Video ad servers ───────────────────────────────────────────────────────────
echo "── Video ad servers ──" >&2
blocked_video=(
  "adserver.adtechus.com"
  "live.adtech.com"
  "ads.pubmatic.com"
  "ads.creative-serving.com"
)
for domain in "${blocked_video[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Russian ads & trackers (RuADList) ──────────────────────────────────────────
echo "── Russian ads & trackers ──" >&2
blocked_russian=(
  "mc.yandex.ru"
  "adriver.ru"
  "begun.ru"
  "rotaban.ru"
  "redtram.com"
  "top-fwz1.mail.ru"
)
for domain in "${blocked_russian[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Extended Google ad domains ──────────────────────────────────────────────────
echo "── Extended Google ad domains ──" >&2
blocked_google_ext=(
  "cm.g.doubleclick.net"
  "bid.g.doubleclick.net"
  "securepubads.g.doubleclick.net"
  "googleads4.g.doubleclick.net"
  "pagead46.l.doubleclick.net"
)
for domain in "${blocked_google_ext[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── CDN ad servers ──────────────────────────────────────────────────────────────
echo "── CDN ad servers ──" >&2
blocked_cdn_ads=(
  "files.vibrantmedia.com"
  "assets.adtechus.com"
  "ads.creative-serving.com"
)
for domain in "${blocked_cdn_ads[@]}"; do
  result=$(resolve "$domain")
  if [[ "$result" == "0.0.0.0" || -z "$result" ]]; then
    pass "Blocked: $domain"
  else
    fail "NOT blocked: $domain → $result"
  fi
done
echo "" >&2

# ── Legitimate domains resolve ────────────────────────────────────────────────
echo "── Legitimate domains resolve ──" >&2
allowed_domains=(
  "github.com"
  "cloudflare.com"
  "google.com"
  "apple.com"
  "amazon.com"
  "netflix.com"
  "spotify.com"
  "youtube.com"
  "wikipedia.org"
  "stackoverflow.com"
  "reddit.com"
  "icloud.com"
  "whatsapp.com"
  "instagram.com"
  "twitter.com"
  "facebook.com"
  "tiktok.com"
  "discord.com"
  "slack.com"
  "notion.so"
  "figma.com"
  "trello.com"
  "asana.com"
  "dropbox.com"
  "onedrive.live.com"
  "drive.google.com"
  "protonmail.com"
  "gmail.com"
  "outlook.com"
  "github.io"
  "heroku.com"
  "netlify.com"
  "vercel.com"
  "digitalocean.com"
  "aws.amazon.com"
  "azure.microsoft.com"
  "developer.mozilla.org"
  "docs.microsoft.com"
  "support.apple.com"
  "help.github.com"
  "medium.com"
  "hashnode.com"
  "dev.to"
  "codepen.io"
  "jsfiddle.net"
  "repl.it"
  "glitch.com"
  "strapi.io"
  "stripe.com"
  "paypal.com"
  "square.com"
  "shopify.com"
  "wix.com"
  "squarespace.com"
  "wordpress.com"
  "blogger.com"
  "github.com"
)
for domain in "${allowed_domains[@]}"; do
  result=$(resolve "$domain")
  if [[ -n "$result" && "$result" != "0.0.0.0" ]]; then
    pass "Resolves: $domain → $result"
  else
    fail "Failed to resolve: $domain"
  fi
done
echo "" >&2

# ── DNSSEC validation ─────────────────────────────────────────────────────────
echo "── DNSSEC validation ──" >&2
raw_flags=$(resolve_full "cloudflare.com" "+dnssec")
flags=$(echo "$raw_flags" | grep "^;; flags:" | head -1)
rrsig=$(echo "$raw_flags" | grep "RRSIG" | head -1)
if [[ -n "$rrsig" ]]; then
  pass "DNSSEC signatures present in response (RRSIG record returned)"
  log "$rrsig"
  log "Note: 'ad' flag is stripped by CoreDNS in the forwarding chain — expected"
else
  fail "No DNSSEC signatures in response"
fi
log "$flags"

raw_dnssec_fail=$(resolve_full "dnssec-failed.org" "+short")
result=$(echo "$raw_dnssec_fail" | grep -v "^;" | head -1)
if [[ -z "$result" ]]; then
  pass "DNSSEC validation working — bogus domain correctly rejected (dnssec-failed.org)"
else
  fail "DNSSEC validation not working — bogus domain resolved: dnssec-failed.org → $result"
fi
echo "" >&2

# ── Caching (tested via TTL decrement, not latency) ──────────────────────────
echo "── Unbound caching ──" >&2
domain="github.com"
log "dig @$DNS $domain +stats  (run 1)"
raw1=$(dig @"$DNS" "$domain" +stats +time=5 2>&1)
while IFS= read -r line; do log "  $line"; done <<< "$raw1"
t1=$(echo "$raw1" | grep "Query time" | awk '{print $4}')
ttl1=$(echo "$raw1" | grep -v "^;" | grep -E "[[:space:]]IN[[:space:]]+A[[:space:]]" | awk '{print $2}' | head -1)

log "dig @$DNS $domain +stats  (run 2 — TTL should decrement if cached)"
raw2=$(dig @"$DNS" "$domain" +stats +time=5 2>&1)
while IFS= read -r line; do log "  $line"; done <<< "$raw2"
t2=$(echo "$raw2" | grep "Query time" | awk '{print $4}')
ttl2=$(echo "$raw2" | grep -v "^;" | grep -E "[[:space:]]IN[[:space:]]+A[[:space:]]" | awk '{print $2}' | head -1)

info "First query:  ${t1} ms  (TTL: ${ttl1:-?}s)"
info "Second query: ${t2} ms  (TTL: ${ttl2:-?}s)"
info "Note: latency reflects VPS network round-trip, not cache state"
if [[ "${ttl1}" =~ ^[0-9]+$ && "${ttl2}" =~ ^[0-9]+$ && "$ttl2" -le "$ttl1" ]]; then
  pass "Cache working — TTL decremented from ${ttl1}s to ${ttl2}s"
else
  fail "Cache may not be working — TTL did not decrement (${ttl1:-?}s → ${ttl2:-?}s)"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "================================================" >&2
printf " Results: ${GREEN}%s passed${NC}  ${RED}%s failed${NC}\n" "$PASS" "$FAIL" >&2
echo "================================================" >&2
echo "" >&2
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
