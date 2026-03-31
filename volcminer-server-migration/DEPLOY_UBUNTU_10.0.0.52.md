# Ubuntu 24 Deployment Guide for 10.0.0.52

This service is designed to coexist with HashSentry on the same server.

## 1. Install Node.js and npm

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
node -v
npm -v
```

Expected:

- `node >= 20`
- `npm` installed with Node.js

## 2. Create isolated directories

```bash
sudo mkdir -p /opt/volcminer-server-migration
sudo mkdir -p /var/log/volcminer-server-migration
sudo chown -R www-data:www-data /opt/volcminer-server-migration
sudo chown -R www-data:www-data /var/log/volcminer-server-migration
```

## 3. Upload the project

From your local machine:

```bash
scp -r volcminer-server-migration itsminer@10.0.0.52:/tmp/
```

On the server:

```bash
sudo rsync -a /tmp/volcminer-server-migration/ /opt/volcminer-server-migration/
sudo chown -R www-data:www-data /opt/volcminer-server-migration
```

## 4. Create runtime config

```bash
cd /opt/volcminer-server-migration
sudo -u www-data cp .env.example .env
sudo -u www-data nano .env
```

Recommended first-pass values:

```env
HOST=127.0.0.1
PORT=18080
POLL_INTERVAL_MS=900000
SCHEDULER_TICK_MS=30000
SCAN_CONCURRENCY=500
SCHEDULER_INITIAL_DELAY_MS=120000
SKIP_IF_HASHSENTRY_ACTIVE=true
CPU_LOAD_GUARD_RATIO=0.9
MIN_AVAILABLE_MEMORY_MB=4096
MAX_HASHSENTRY_SCAN_PROCESSES=1
```

## 5. Configure miners

Edit:

```bash
sudo -u www-data nano /opt/volcminer-server-migration/config/miners.json
```

Start with `50-200` miners only.

Keep `enabled: false` on any templates you do not want to scan yet.

## 6. Smoke test before service install

```bash
cd /opt/volcminer-server-migration
sudo -u www-data node src/server.js
```

In another shell:

```bash
curl http://127.0.0.1:18080/health
curl http://127.0.0.1:18080/api/system/scheduler
```

Stop with `Ctrl+C` after the test.

## 7. Install systemd service

```bash
sudo cp /opt/volcminer-server-migration/deploy/systemd/volcminer-aggregator.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable volcminer-aggregator
sudo systemctl start volcminer-aggregator
sudo systemctl status volcminer-aggregator --no-pager
```

## 8. Optional nginx exposure

If you want direct access without touching HashSentry on `8000`:

```bash
sudo cp /opt/volcminer-server-migration/deploy/nginx/volcminer-aggregator.conf /etc/nginx/sites-available/volcminer-aggregator.conf
sudo ln -s /etc/nginx/sites-available/volcminer-aggregator.conf /etc/nginx/sites-enabled/volcminer-aggregator.conf
sudo nginx -t
sudo systemctl reload nginx
```

This template uses:

- application: `127.0.0.1:18080`
- nginx external listener: `18081`

If you already have a shared nginx vhost, prefer a dedicated path such as `/miner-api/`.

## 9. Runtime checks

```bash
ss -lntp | grep 18080
curl http://127.0.0.1:18080/api/system/health
curl http://127.0.0.1:18080/api/system/scheduler
journalctl -u volcminer-aggregator -n 100 --no-pager
```

## 10. Rollout sequence

1. Start with `50-200` miners.
2. Observe several `15` minute cycles.
3. Check CPU, memory, load, and delay behavior while HashSentry is also active.
4. Expand to `500-1000` miners only after stability is confirmed.
5. Scale toward `6000` only after repeated stable windows.

## 11. Rollback

```bash
sudo systemctl stop volcminer-aggregator
sudo systemctl disable volcminer-aggregator
sudo rm -f /etc/systemd/system/volcminer-aggregator.service
sudo systemctl daemon-reload
```

This rollback does not touch HashSentry on `8000`.
