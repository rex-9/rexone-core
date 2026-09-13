# Production DDoS and API Abuse Protection

This guide hardens Rexone Core's current Coolify, Traefik, Rails, Rack Attack,
Garage, and worker deployment. Apply changes gradually in UAT, observe normal
traffic, and then promote the same configuration to production.

> [!IMPORTANT]
> No application setting makes a service "DDoS proof." Rack Attack protects
> Rails from endpoint abuse and brute-force traffic that reaches the process.
> Cloudflare and the origin firewall must reject volumetric traffic before it
> consumes VPS bandwidth, sockets, memory, or Puma threads.

## Defense model

Use four defensive layers:

```text
Internet
   ↓
Cloudflare — absorbs network/HTTP floods, WAF, bots, edge rate limits
   ↓
Coolify/Traefik — connection limits and request-size limits
   ↓
Rack Attack — endpoint-specific and account-aware limits
   ↓
Rails/Puma — bounded threads, queues, timeouts, database pools
```

## 1. Put every public hostname behind Cloudflare

Add your domain to Cloudflare and ensure these DNS records are proxied—the orange cloud:

- `app.example.com` → Rexone Web
- `api.example.com` → Rexone Core
- Your public Garage download hostname, if appropriate

Do not proxy Garage’s administration endpoint or PostgreSQL.

Cloudflare’s managed DDoS protection is automatic and detects network and HTTP attack patterns before traffic reaches your server. [Cloudflare DDoS documentation](https://developers.cloudflare.com/ddos-protection/about/how-ddos-protection-works/)

Use:

- SSL/TLS mode: `Full (strict)`
- Always Use HTTPS: enabled
- Minimum TLS: 1.2
- HTTP DDoS managed rules: enabled
- Cloudflare managed WAF rules: enabled if included in your plan

## 2. Prevent attackers from bypassing Cloudflare

This is the most important part. If attackers discover the VPS IP and port `3000`, they can bypass Cloudflare completely.

Your production Compose currently publishes Rails publicly:

```yaml
ports:
  - "${RAILS_PORT_MAP:-3000:3000}"
```

For Coolify, Rails should normally be reachable only through its internal Docker network and Traefik. Prefer:

```yaml
expose:
  - "3000"
```

Do the same for Garage unless its raw S3 endpoint genuinely needs direct public access.

At the VPS firewall:

- Allow inbound `80` and `443`.
- Allow SSH only from trusted IPs or through a VPN.
- Do not expose `3000`, `3100`, `3101`, or `5432`.
- Keep Garage admin port `3101` private.
- Keep PostgreSQL entirely private.

For stronger origin lockdown, allow HTTP/HTTPS traffic only from Cloudflare IP ranges or use Cloudflare Tunnel. Cloudflare also recommends ensuring the origin cannot be accessed directly. [Cloudflare proactive defense](https://55041f86.previews.developers.cloudflare.com/ddos-protection/best-practices/proactive-defense/)

Be careful: restricting ports 80/443 to Cloudflare requires an automated process to keep Cloudflare IP ranges current.

### Verify origin isolation

From a machine outside the VPS network:

```bash
# The Cloudflare hostname should succeed.
curl -I https://api.example.com/up

# Direct access to the origin application port should time out or be refused.
curl --connect-timeout 5 http://ORIGIN_IP:3000/up
```

Do not put credentials, tokens, or signed Garage URLs in shell history while
performing these checks.

## 3. Add Cloudflare rate-limit rules

Create rules under Security → WAF → Rate limiting rules.

Start conservatively and observe real usage before blocking aggressively.

### Sign-in protection

Expression:

```text
(http.host eq "api.example.com"
 and http.request.method eq "POST"
 and http.request.uri.path eq "/signin")
```

Suggested limit:

- 10 requests per minute per IP
- Mitigation: Managed Challenge
- Duration: 10 minutes

Rack Attack already allows 10 per five minutes. The Cloudflare limit stops excess requests before they consume Rails resources.

### Registration and password recovery

Expression:

```text
(http.host eq "api.example.com"
 and http.request.method in {"POST" "PUT"}
 and (
   starts_with(http.request.uri.path, "/signup")
   or starts_with(http.request.uri.path, "/password")
   or starts_with(http.request.uri.path, "/confirmation")
 ))
```

Suggested limit:

- 20 requests per minute per IP
- Managed Challenge or block
- Duration: 10 minutes

### Client telemetry

`POST /v1/client/logs` is unauthenticated, so attackers could use it to fill storage or consume database capacity.

Suggested limit:

- 30 requests per minute per IP
- Burst allowance if available
- Block for 10 minutes

### AI and speech endpoints

These are expensive and should have stricter account-based server limits in addition to IP limits:

- `/v1/ai/*`: perhaps 30 requests/minute
- `/v1/speech/*`: perhaps 10 requests/minute
- Enforce user quotas inside Rails—not solely by IP, because many legitimate mobile users can share one carrier IP.

Cloudflare documents rate-limit rules specifically for login and API abuse prevention. [Cloudflare rate-limiting rules](https://developers.cloudflare.com/waf/rate-limiting-rules/)

### Safe rollout

1. Create one rule at a time.
2. Use logging or Managed Challenge before a hard block when the plan supports it.
3. Observe Security Events and origin `429` rates for at least one normal traffic cycle.
4. Exclude trusted health monitors only when they use stable, controlled addresses.
5. Promote the thresholds to production and document every exception.

Do not exempt requests based on a client-supplied header unless Cloudflare or
another trusted proxy removes incoming copies and sets the header itself.

## 4. Add Traefik protection through Coolify

Traefik supports token-bucket rate limiting, maximum in-flight requests, and request-body limits. [Rate limit](https://doc.traefik.io/traefik/master/reference/routing-configuration/http/middlewares/ratelimit/), [in-flight requests](https://doc.traefik.io/traefik/master/reference/routing-configuration/http/middlewares/inflightreq/), [request buffering](https://doc.traefik.io/traefik/master/reference/routing-configuration/http/middlewares/buffering/)

Conceptually, your API service needs middleware equivalent to:

```yaml
labels:
  - "traefik.http.middlewares.rexone-api-rate.ratelimit.average=50"
  - "traefik.http.middlewares.rexone-api-rate.ratelimit.period=1s"
  - "traefik.http.middlewares.rexone-api-rate.ratelimit.burst=100"

  - "traefik.http.middlewares.rexone-api-inflight.inflightreq.amount=100"

  - "traefik.http.middlewares.rexone-api-body.buffering.maxRequestBodyBytes=5242880"
  - "traefik.http.middlewares.rexone-api-body.buffering.memRequestBodyBytes=1048576"
```

Then attach them to the Coolify-generated API router:

```yaml
- "traefik.http.routers.<coolify-api-router>.middlewares=rexone-api-rate,rexone-api-inflight,rexone-api-body"
```

The exact router name is generated by Coolify, so inspect the deployed container’s Traefik labels before setting this.

Before editing labels, record the current router name and middleware chain so
the change can be rolled back. After deployment, verify that ordinary API calls,
WebSocket upgrades, uploads, and health checks still work.

Important: a global 5 MB body limit would break media uploads. Ideally use two routers:

- General API: 1–5 MB maximum
- `/v1/assets/upload` and admin asset uploads: slightly above your actual maximum supported media size

Your videos currently permit large files, so avoid a buffering middleware that makes Traefik spool hundreds of megabytes through memory/disk. The best long-term design is direct presigned uploads to Garage, followed by a lightweight Rails request that registers the completed asset.

## 5. Make Rack Attack proxy-aware

Once Cloudflare and Traefik are in front, verify that `req.ip` is the actual client IP—not Cloudflare or Traefik’s IP.

If every request appears to originate from one proxy IP, the first ten sign-in attempts across all users could throttle everyone.

Rails must trust only your actual proxy network or known Cloudflare ranges. Never trust arbitrary `X-Forwarded-For` headers from the open Internet.

Test production headers by logging these temporarily:

```ruby
Rails.logger.info(
  remote_ip: request.remote_ip,
  forwarded_for: request.headers["X-Forwarded-For"],
  cf_connecting_ip: request.headers["CF-Connecting-IP"]
)
```

Then make a normal request through Cloudflare and confirm `request.remote_ip` is your client address.

Remove temporary IP logging after verification. IP addresses are operational
data and should not be retained indefinitely without a defined purpose and
retention policy.

## 6. Expand Rack Attack beyond authentication

Useful server-side limits:

- `POST /v1/client/logs`: per IP
- `POST /v1/feedbacks`: per user and IP
- `/v1/ai/*`: per authenticated user
- `/v1/speech/*`: per authenticated user
- Media upload initialization: per user
- Stripe webhook: do not apply a simplistic IP throttle; authenticate using Stripe signatures
- `/up`: allow monitoring, but stop extremely high request rates

Use separate limits for:

- Anonymous IP
- Authenticated user ID
- Expensive endpoint
- General API fallback

Do not use only a broad global per-IP limit. Mobile carrier NAT, offices, monasteries, schools, and VPNs may place many legitimate users behind one address.

## 7. Bound Rails resource consumption

For your current setup:

- Keep `RAILS_MAX_THREADS` and `API_DB_POOL` equal.
- Start with one Puma process and 5–7 threads on a small VPS.
- Give API, normal jobs, and media workers separate CPU/memory limits.
- Keep media work in the dedicated `media` worker.
- Add timeouts around Stripe, OneSignal, DeepSeek, Garage, and other outbound calls.
- Limit queue concurrency so a flood cannot start unlimited FFmpeg processes.
- Alert on elevated `429`, `413`, `5xx`, queue depth, memory, CPU, and database connections.

## 8. Test the protection safely

Never perform load or flood testing against production without explicit provider
approval. Cloudflare, the VPS provider, or adjacent tenants may interpret it as
an attack.

Use UAT and test one control at a time:

```bash
# Core regression coverage for the Rack Attack rules.
docker compose -f docker-compose.dev.yaml exec api \
  bundle exec rspec spec/requests/rack_attack_spec.rb
```

For external testing, send only enough requests to cross the configured UAT
threshold. Confirm:

- Cloudflare or Traefik returns `429` before the request reaches Rails.
- Rack Attack returns its JSON error envelope and `Retry-After` header when the
  edge deliberately allows the test through.
- A different test IP is not accidentally sharing the same rate-limit bucket.
- Mobile clients handle `429` without retry loops.
- Uploads above the configured limit return `413` without consuming a Rails worker.
- Action Cable connections and normal API traffic remain healthy.

## 9. Monitoring and incident response

Create alerts for unusual changes in:

- Cloudflare challenged and blocked requests.
- Traefik `429` and `413` responses.
- Rails `429`, `5xx`, latency, and Puma saturation.
- Database connections and slow queries.
- Solid Queue depth, failed jobs, and retry volume.
- API, worker, media-worker, and Garage CPU, memory, disk, and network usage.

During an incident:

1. Confirm whether traffic reaches Cloudflare, Traefik, or Rails.
2. Preserve a short sample of request metadata without recording secrets.
3. Add the narrowest effective edge rule for the observed path or fingerprint.
4. Reduce expensive endpoint concurrency if the application is saturated.
5. Avoid broad country or ASN blocks unless evidence supports them.
6. Review false positives and remove temporary emergency rules after traffic normalizes.

## Rollback

If legitimate users are blocked:

1. Disable the newest Cloudflare rule or switch it from Block to Log/Challenge.
2. Detach the newest Traefik middleware from the router before deleting its definition.
3. Restore the previous body-size and in-flight limits.
4. Confirm Rails receives the correct client IP.
5. Retest sign-in, password recovery, uploads, AI, speech, and sockets.

## Recommended priority

Do these first:

1. Proxy the API through Cloudflare.
2. Remove direct public access to ports `3000`, `3101`, and `5432`.
3. Confirm Rails sees the real client IP.
4. Add Cloudflare rules for sign-in, password, client logs, AI, and speech.
5. Add Traefik in-flight and body-size limits.
6. Add user-based Rack Attack limits for expensive endpoints.
7. Move large uploads to presigned direct-to-Garage uploads.

The biggest immediate risk in the current Compose configuration is the public `3000:3000` port mapping. If that port is externally reachable, Cloudflare protection can be bypassed entirely.

## References

- [Cloudflare: How DDoS protection works](https://developers.cloudflare.com/ddos-protection/about/how-ddos-protection-works/)
- [Cloudflare: Rate limiting rules](https://developers.cloudflare.com/waf/rate-limiting-rules/)
- [Cloudflare: Rate limiting best practices](https://developers.cloudflare.com/waf/rate-limiting-rules/best-practices/)
- [Traefik: RateLimit middleware](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ratelimit/)
- [Traefik: InFlightReq middleware](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/inflightreq/)
- [Traefik: Buffering middleware](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/buffering/)
