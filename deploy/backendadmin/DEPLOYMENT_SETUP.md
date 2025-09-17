# LiveKit Admin Deployment Setup Guide

## Prerequisites

### 1. Environment Variables
Create `.env` file with LiveKit credentials:
```bash
LIVEKIT_API_KEY=your_api_key_here
LIVEKIT_API_SECRET=your_api_secret_here
```

These will be automatically picked up by Kamal from the `.env` file as configured in `config/deploy.yml`.

### 2. Server Requirements
- Hetzner server with Docker installed
- Root SSH access
- Ports 80 and 443 available

## Initial Setup Steps

### 1. Configure Environment
```bash
# Copy example environment file
cp .env.example .env

# Edit .env and add your LiveKit credentials
# LIVEKIT_API_KEY and LIVEKIT_API_SECRET
```

### 2. Install Solid Queue Locally (Rails 8 Active Job)
```bash
# Add to Gemfile if not present
bundle add solid_queue

# Install Solid Queue
bin/rails generate solid_queue:install

# This creates:
# - config/solid_queue.yml
# - db/queue_schema.rb
# - Updates config/environments/production.rb

# Run migrations locally to create schema
bin/rails db:create
bin/rails db:migrate
bin/rails db:migrate:queue
```

### 3. Setup Server Volumes (One-time)
```bash
# Run the setup script to configure server volumes
./setup_server_volumes.sh

# Or manually:
ssh root@157.180.124.104 "mkdir -p /data/livekit-admin/storage /data/livekit-admin/db /data/livekit-admin/videos"
ssh root@157.180.124.104 "chown -R 1000:1000 /data/livekit-admin/"
```

## Deployment Options

### Option 1: Regular Deployment
```bash
kamal deploy
```

### Option 2: Clean Slate Deployment
Use this when you need to completely reset everything:
```bash
./clean_deploy.sh
```

This script will:
1. Clean all local Docker resources
2. Remove all Docker builders
3. Clean Kamal temporary files
4. Clean remote Docker resources on Hetzner
5. Setup server volume permissions
6. Create fresh buildx builder
7. Deploy from scratch

### Option 3: Quick Redeploy (after code changes)
```bash
git add -A
git commit -m "Your changes"
kamal deploy
```

## Verification

### Run Smoke Tests
```bash
./smoke_test_with_queue.sh
```

Expected results:
- ✅ Health check (/up)
- ✅ Videos endpoint (/videos)
- ✅ Root endpoint (/)
- ✅ Asset pipeline
- ✅ Database connectivity
- ✅ Schema caching fix
- ⚠️ Solid Queue UI (404 is expected in production)

### Check Application Logs
```bash
# View recent logs
kamal app logs --lines 50

# Follow logs in real-time
kamal app logs --follow
```

## Troubleshooting

### Permission Issues
If you see "unable to open database file" errors:
```bash
ssh root@157.180.124.104 "chown -R 1000:1000 /data/livekit-admin/"
```

### Schema Caching Issues
Already fixed in `app/models/video.rb` with `table_exists?` checks.

### Database Not Created
Check `docker-entrypoint` script - it should run:
```bash
./bin/rails db:prepare
./bin/rails db:create:cache 2>/dev/null || true
./bin/rails db:create:queue 2>/dev/null || true
./bin/rails db:create:cable 2>/dev/null || true
```

### Ingress Issues
The Video model handles ingress creation/management. Check logs for ingress errors:
```bash
kamal app logs | grep -i ingress
```

## Key Files Modified for Deployment

1. **`app/models/video.rb`**
   - Added `table_exists?` checks to all scopes to prevent schema caching errors

2. **`bin/docker-entrypoint`**
   - Removed problematic `chown` commands
   - Added individual database creation for Rails 8 multi-db setup
   - Creates videos directory without permission changes

3. **`Dockerfile`**
   - Creates rails user with UID 1000
   - Sets up proper directory structure
   - No runtime permission changes needed

4. **`config/deploy.yml`**
   - Configured LiveKit environment variables
   - Set up volume mounts for persistent storage

## Production URLs
- Admin Panel: https://admin.livekit.lovedrop.live
- LiveKit Server: https://livekit.lovedrop.live

## Important Notes

1. **UID Alignment**: The Rails container user has UID 1000, which must match the server volume ownership.

2. **Multi-Database Setup**: Rails 8 uses separate databases for cache, queue, and cable. The docker-entrypoint handles this.

3. **No Runtime Permission Changes**: All permission setup is done on the server before deployment, not in the container.

4. **Solid Queue**: The web UI endpoint `/rails/solid_queue/overview` returns 404 in production - this is expected as it's not mounted in production routes.