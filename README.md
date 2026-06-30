# Pi-hole + Unbound DNS Stack on Vultr Miami VPS

A production-ready recursive DNS resolver with ad-blocking, DNSSEC validation, and WireGuard VPN integration. Blocks **523K+ domains** across 6 curated blocklists with zero third-party DNS upstream dependency.

## Architecture

```
WireGuard Client (Mac/Android/Linux)
    ↓
CoreDNS (10.13.13.1:53)
    ↓
Pi-hole (172.19.0.1:53) — Ad blocking, query logging
    ↓
Unbound (172.20.0.3:5335) — Recursive DNSSEC resolver
    ↓
Root Name Servers (direct connection)
```

## Features

- ✅ **Recursive DNS** — Queries root servers directly, no Google/Cloudflare/Quad9 upstream
- ✅ **DNSSEC Validation** — Full chain validation with signature verification
- ✅ **523K+ Blocked Domains** — 6 curated blocklists (ads, tracking, malware, regional)
- ✅ **WireGuard VPN** — All clients route DNS through Pi-hole automatically
- ✅ **Web Dashboard** — `https://dns.rmontero.me` with Cloudflare Zero Trust auth
- ✅ **Comprehensive Tests** — 130+ automated tests covering all blocking categories

## Quick Start

### 1. Deploy Stack

```bash
cd ~/repos/pihole
docker compose up -d
```

### 2. Add Blocklists

Add all blocklists to Pi-hole (run on Vultr server):

```bash
# 1. StevenBlack (82K general ads)
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 1, 'StevenBlack (General ads)');"

# 2. YouTube ads (6K)
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "INSERT INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/kboghdady/youTube_ads_4_pi-hole/master/crowed_list.txt', 1, 'YouTube ads list');"

# 3. OISD big (336K comprehensive)
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "INSERT INTO adlist (address, enabled, comment) VALUES ('https://big.oisd.nl', 1, 'OISD big (Comprehensive)');"

# 4. RuADList + EasyList (45K Russian ads)
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "INSERT INTO adlist (address, enabled, comment) VALUES ('https://easylist-downloads.adblockplus.org/ruadlist+easylist.txt', 1, 'RuADList + EasyList (Russian ads)');"

# 5. Fanboy Social (social media tracking widgets)
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "INSERT INTO adlist (address, enabled, comment) VALUES ('https://easylist-downloads.adblockplus.org/fanboy-social.txt', 1, 'Fanboy Social Blocklist');"

# 6. Adguard DNS (152K comprehensive ads/tracking/malware)
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "INSERT INTO adlist (address, enabled, comment) VALUES ('https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt', 1, 'Adguard DNS filter');"

# Update gravity to pull all lists
docker exec pihole pihole -g
```

**Total blocklists:** 6  
**Total unique domains:** 523,842

### 3. Run Tests

Test your blocklist from any WireGuard-connected device:

```bash
cd ~/Repos/pihole
./test.sh

# Or specify a different resolver
./test.sh 127.0.0.1      # From the server
./test.sh 10.13.13.1     # Via WireGuard (default)
```

**Test categories:**
- Ad networks (Google, Meta, Twitter, etc.) — 12 domains
- Tracking & telemetry — 9 domains
- YouTube ads — 4 domains
- Marketing pixels & retargeting — 15 domains
- Russian ads & trackers — 6 domains
- Extended Google ads — 5 domains
- CDN ad servers — 3 domains
- DNSSEC validation — 2 tests
- Unbound caching — 1 test
- Legitimate domains — 60+ domains

## Configuration Files

### `docker-compose.yaml`
- Pi-hole service on `dns_net` (172.20.0.2) and `taurus` (nginx network)
- Unbound recursive resolver on `dns_net` (172.20.0.3)
- Health checks for automatic startup ordering
- Both services isolated from public internet

### `unbound/unbound.conf`
- Recursive resolution to root servers
- DNSSEC full validation
- Access control locked to Pi-hole only (172.20.0.0/29)
- Performance tuning: 2 threads, 256MB RRset cache, 128MB msg cache
- Private address ranges protected (192.168.0.0/16, 172.16.0.0/12, 10.0.0.0/8)

### `unbound/root.hints`
- Root nameserver hints (updated May 2026)
- Required for Unbound to bootstrap resolution

### `nginx.conf`
- HTTP → HTTPS redirect
- ACME challenge support for Let's Encrypt
- SSL proxy to Pi-hole web UI
- Internal routing via container name on `taurus` network

### `test.sh`
- 130+ automated tests
- Validates ad blocking, tracking prevention, DNSSEC, caching
- Color-coded output (green = pass, red = fail)
- Runs in ~2 minutes

## Network Configuration

### Host firewall (UFW)

```bash
# Allow WireGuard peers to query DNS
ufw allow from 10.13.13.0/24 to any port 53 comment "WireGuard clients DNS"

# Allow from WireGuard server if separate
ufw allow from 148.113.167.244 to any port 53 comment "WireGuard server DNS"

# Keep port 53 closed from public (Pi-hole not exposed)
```

### Docker networks

- **dns_net** (172.20.0.0/29) — Pi-hole ↔ Unbound (isolated)
- **taurus** (172.18.0.0/16) — Nginx ↔ Pi-hole (reverse proxy)

## Testing DNS Resolution

```bash
# From Mac/WireGuard client
dig @10.13.13.1 google.com +short
# Should return IP (e.g., 142.251.35.110)

dig @10.13.13.1 doubleclick.net +short
# Should return 0.0.0.0 (blocked)

dig @10.13.13.1 cloudflare.com +dnssec | grep flags
# Should show: flags: qr rd ra ad; (ad = authenticated data)
```

## Monitoring

Check blocklist status:

```bash
# View gravity database
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "SELECT id, address, comment, number FROM adlist ORDER BY id;"

# Check total blocked domains
docker exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
  "SELECT COUNT(*) FROM gravity;"

# View query log live
docker exec pihole pihole tail

# Check query statistics
docker exec pihole pihole api gravity/summary
```

## Troubleshooting

### Unbound not starting
- Check root.key exists: `docker exec unbound ls /opt/unbound/etc/unbound/var/root.key`
- Verify Corefile path is correct in unbound.conf
- Check logs: `docker logs unbound`

### Pi-hole reports 403 Forbidden
- Run: `docker compose up -d --force-recreate pihole`
- Verify `FTLCONF_webserver_acl: '+0.0.0.0/0'` is set (internal only access)

### Queries not reaching Pi-hole via WireGuard
- Check CoreDNS config: `cat ~/repos/wireguard/config/coredns/Corefile`
- Should have: `forward . 172.19.0.1`
- Restart CoreDNS: `docker exec wireguard s6-svc -r /run/service/svc-coredns`

### SSL certificate issues
- DNS record must be live: `dig dns.rmontero.me +short`
- Run certbot: `docker compose run --rm certbot certonly --webroot --webroot-path /var/www/certbot -d dns.rmontero.me`
- Swap to HTTPS nginx config after cert is issued

## Security Considerations

- ✅ Pi-hole port 53 NOT exposed to public internet (blocked by UFW)
- ✅ Only WireGuard clients can query Pi-hole
- ✅ Web UI protected by Cloudflare Zero Trust authentication
- ✅ All DNS queries encrypted over WireGuard tunnel
- ✅ DNSSEC validates all responses from root servers
- ✅ Private address ranges (RFC 1918) excluded from resolution
- ⚠️ Unbound listens on 5335 internally only (172.20.0.0/29 ACL)

## Performance

- **Query latency:** ~90ms (Vultr Miami → client, through WireGuard)
- **Cache hit latency:** <10ms
- **Concurrent queries:** 4000+ per thread
- **Blocked domains:** 523,842 unique
- **DNS queries per second:** Limited by WireGuard VPN throughput

## Updates

Update blocklists weekly:

```bash
# On Taurus server
docker exec pihole pihole -g
```

Update Unbound root hints every 6 months:

```bash
curl -o ~/repos/pihole/unbound/root.hints https://www.internic.net/domain/named.cache
docker compose up -d unbound
```

## References

- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Manual](https://nlnetlabs.nl/documentation/unbound/)
- [DNSSEC Primer](https://dnssec.verifying.co/)
- [OISD Blocklist](https://oisd.nl/)
- [EasyList Filters](https://easylist.to/)
