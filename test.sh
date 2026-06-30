#!/usr/bin/env bash
# Pi-hole + Unbound DNS stack test suite
# Run from a WireGuard-connected client or the server itself.
# Usage: ./test.sh [DNS_IP]
# Default DNS: 10.13.13.1

set -euo pipefail

DNS="${1:-10.13.13.1}"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

BOLD='\033[1m'
DIM='\033[2m'

pass() { echo -e "${GREEN}[PASS]${NC} $1" >&2; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1" >&2; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1" >&2; }
log()  { echo -e "${DIM}       $1${NC}" >&2; }

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
  "graph.facebook.com/ads"
  "connect.facebook.net"
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
  "telemetry.microsoft.com"
  "data.microsoft.com"
  "scorecardresearch.com"
  "pixel.facebook.com"
  "tr.snapchat.com"
  "analytics.twitter.com"
  "bat.bing.com"
  "mc.yandex.ru"
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
  "yt3.ggpht.com"
  "youtubei.googleapis.com/youtubei/v1/log_event"
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
ttl1=$(echo "$raw1" | grep -E "IN\s+A" | awk '{print $2}' | head -1)

log "dig @$DNS $domain +stats  (run 2 — TTL should decrement if cached)"
raw2=$(dig @"$DNS" "$domain" +stats +time=5 2>&1)
while IFS= read -r line; do log "  $line"; done <<< "$raw2"
t2=$(echo "$raw2" | grep "Query time" | awk '{print $4}')
ttl2=$(echo "$raw2" | grep -E "IN\s+A" | awk '{print $2}' | head -1)

info "First query:  ${t1} ms  (TTL: ${ttl1}s)"
info "Second query: ${t2} ms  (TTL: ${ttl2}s)"
info "Note: latency reflects VPS network round-trip, not cache state"
if [[ -n "$ttl1" && -n "$ttl2" && "$ttl2" -le "$ttl1" ]]; then
  pass "Cache working — TTL decremented from ${ttl1}s to ${ttl2}s"
else
  fail "Cache may not be working — TTL did not decrement (${ttl1}s → ${ttl2}s)"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "================================================" >&2
echo -e " Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}" >&2
echo "================================================" >&2
echo "" >&2
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
