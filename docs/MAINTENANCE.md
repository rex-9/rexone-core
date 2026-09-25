# Automated Telemetry, Log Rotation & Data Retention Guide

> **Single-Pane-of-Glass Reference**: All periodic cleanups, log rotations, and data retention schedules running across RexOne Core in both production and development.

---

## ⚡ At a Glance: Retention Matrix

| Subsystem / Target | Retention Window | Schedule / Frequency | Mechanism / Job | Config File |
| :--- | :--- | :--- | :--- | :--- |
| **Docker Container Logs** | Max 30 MB / container (`10m` $\times$ 3 files) | Continuous runtime rotation | Docker `json-file` rotation | [`docker-compose.yaml`](../docker-compose.yaml), [`docker-compose.dev.yaml`](../docker-compose.dev.yaml) |
| **Rails Pulse (Requests & Queries)** | **1 month** (max 50k req / 250k ops) | Daily at 01:00 AM | `RailsPulse::CleanupJob` | [`config/initializers/rails_pulse.rb`](../config/initializers/rails_pulse.rb), [`config/recurring.yml`](../config/recurring.yml) |
| **Rails Pulse (Summary Rollups)** | Permanent aggregated charts | Hourly at minute :05 | `RailsPulse::SummaryJob` | [`config/recurring.yml`](../config/recurring.yml) |
| **Solid Queue Failed Jobs** | **1 month** (`1.month.ago`) | Weekly on Sunday at 03:00 AM | `clear_solid_queue_failed_jobs` | [`config/recurring.yml`](../config/recurring.yml) |
| **Solid Queue Finished Jobs** | Continuous batch clean | Hourly at minute :12 | `clear_solid_queue_finished_jobs` | [`config/recurring.yml`](../config/recurring.yml) |
| **Solid Cache Entries** | **24 hours** (`1.day.ago`) | Daily at 02:00 AM | `clear_solid_cache_expired_entries` | [`config/recurring.yml`](../config/recurring.yml) |
| **AI Telemetry (`Ai::Run`)** | **90 days** (`90.days.ago`) | Weekly on Sunday at 04:00 AM | `clear_old_ai_runs` | [`config/recurring.yml`](../config/recurring.yml) |
| **Stripe Webhook Records** | **30 days** | Daily at 03:30 AM | `clear_old_payment_webhook_events` | [`config/recurring.yml`](../config/recurring.yml) |
| **User Notifications** | **30 days** (read / discarded) | Daily at 02:30 AM | `notification_cleanup` | [`config/recurring.yml`](../config/recurring.yml) |
| **Docker Images & Build Cache** | **7 days** (168 hours) | Weekly (host cron) | [`./scripts/vps_cleanup.sh`](../scripts/vps_cleanup.sh) | [`.env.example`](../.env.example) |

---

## 1. Docker Container Log Rotation (Continuous)

In production, Rails outputs to `STDOUT` (`config.logger = STDOUT`). Docker captures all standard output into json log files on the host disk. Without rotation, these files grow indefinitely until 100% disk exhaustion occurs.

### How It Works:
Both [`docker-compose.yaml`](../docker-compose.yaml) and [`docker-compose.dev.yaml`](../docker-compose.dev.yaml) define a shared YAML anchor:

```yaml
x-logging: &default-logging
  driver: "json-file"
  options:
    max-size: "${DOCKER_LOG_MAX_SIZE:-10m}"
    max-file: "${DOCKER_LOG_MAX_FILE:-3}"
```

* **Max Size (`10m`)**: When a container log reaches 10 MB, Docker archives it and opens a new file.
* **Max File (`3`)**: Retains only 3 segments. Total disk space per container is strictly capped at **30 MB max**.
* **Zero Downtime**: Docker engine handles rotation natively. No container restarts, log truncation locks, or cron jobs needed.
* **Configurable**: Can be overridden via `.env` (`DOCKER_LOG_MAX_SIZE` and `DOCKER_LOG_MAX_FILE`).

---

## 2. Rails Pulse Performance Telemetry (1 Month Retention)

Rails Pulse tracks all HTTP request durations, P95/P99 latencies, database query times, and background job executions.

### How It Works:
1. **Hourly Summaries (`RailsPulse::SummaryJob`)**:
   - Runs every hour at `:05` via Solid Queue recurring cron.
   - Condenses granular operations into hourly and daily summary rows so historical analytics remain lightning fast.
2. **Daily Pruning (`RailsPulse::CleanupJob`)**:
   - Runs daily at `01:00 AM` via Solid Queue recurring cron.
   - Deletes raw `rails_pulse_requests` and `rails_pulse_operations` older than **1 month** (`config.full_retention_period = 1.month`).
   - Enforces record count safety limits (50k requests, 250k operations, 2.5k routes, 1.5k queries).

---

## 3. Solid Queue & Solid Cache Maintenance

Solid Queue and Solid Cache use PostgreSQL tables instead of Redis. Their retention lifecycle is automated in [`config/recurring.yml`](../config/recurring.yml):

* **Finished Jobs**: Cleared hourly (`minute 12`) in non-blocking batches (`SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)`).
* **Failed Jobs**: Retained for **1 month** (`SolidQueue::Job.where('finished_at IS NOT NULL AND finished_at < ?', 1.month.ago).delete_all`) running every Sunday at `03:00 AM`, giving ample time to inspect failed jobs before recycling.
* **Expired Cache**: Cleared daily at `02:00 AM` (`SolidCache::Entry.where('created_at < ?', 1.day.ago).delete_all`).

---

## 4. AI Runs Telemetry (`Ai::Run` — 90 Days Retention)

The AI Control Plane records every LLM prompt, completion, token breakdown, and error in `ai_runs` (accessible at `/admin/ai/runs`).

* **Retention Window**: **90 days**.
* **Schedule**: Weekly on Sunday at `04:00 AM`.
* **Execution**: `Ai::Run.where('created_at < ?', 90.days.ago).delete_all`.
* **Benefit**: Preserves quarterly telemetry trends while preventing multi-gigabyte raw conversation bloat.

---

## 5. Host VPS Maintenance (`scripts/vps_cleanup.sh`)

For Contabo / Coolify Linux VPS hosts:

```bash
# Recommended Host Cron (runs every Sunday at 03:00 UTC):
0 3 * * 0 /path/to/rexone-core/scripts/vps_cleanup.sh >> /var/log/rexone_vps_cleanup.log 2>&1
```

* Prunes exited/dead containers (`docker container prune -f`).
* Prunes unused deployment images older than 7 days (`IMAGE_RETENTION_HOURS=168`).
* Prunes builder cache older than 7 days (`BUILD_CACHE_RETENTION_HOURS=168`).
* **Absolute Safety**: Never touches database or Garage storage volumes (`rexone-postgres-data`, `rexone-garage-data`).

---

## 🛠️ Instant Manual Cleanup Commands (Cheat Sheet)

If you ever want to force cleanups immediately without waiting for the scheduled cron:

```bash
# 1. Manually run Rails Pulse daily cleanup (inside API container):
docker compose exec api bundle exec rails runner "RailsPulse::CleanupJob.perform_now"

# 2. Manually purge failed jobs older than 1 month:
docker compose exec api bundle exec rails runner "SolidQueue::Job.where('finished_at IS NOT NULL AND finished_at < ?', 1.month.ago).delete_all"

# 3. Manually purge AI runs older than 90 days:
docker compose exec api bundle exec rails runner "Ai::Run.where('created_at < ?', 90.days.ago).delete_all"

# 4. Check Docker container log sizes on the host:
docker ps -q | xargs docker inspect --format='{{.Name}}: {{.LogPath}}' | xargs -n2 sh -c 'ls -lh "$2" 2>/dev/null' _

# 5. Clear local Rails development logs:
bundle exec rake log:clear
```
