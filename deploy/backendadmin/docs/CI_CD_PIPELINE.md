# CI/CD Pipeline & Docker Permissions Strategy

## Overview
This document outlines the CI/CD pipeline architecture and permission handling strategy for Rails Docker deployments on Hetzner using Kamal.

## Permission Architecture

### Standard Solution: UID Alignment
The standard approach for Rails Docker deployments on Hetzner leverages UID alignment between container and host:

1. **Container User**: Rails app runs as `rails` user (UID 1000, GID 1000) inside container
2. **Host User**: Hetzner's `deploy` user also has UID 1000, GID 1000
3. **Volume Ownership**: Host volumes are owned by `deploy:deploy` (1000:1000)

This alignment allows seamless read/write operations without permission issues.

### Implementation Details

#### Dockerfile Configuration
```dockerfile
# Create rails user with UID 1000
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p public/videos && \
    chown -R rails:rails db log storage tmp public/videos
USER 1000:1000
```

#### Host Volume Setup
```bash
# One-time setup on Hetzner server
sudo chown -R deploy:deploy /data/livekit-admin/videos
sudo chown -R deploy:deploy /data/livekit-admin/storage
sudo chown -R deploy:deploy /data/livekit-admin/db
```

#### Kamal Volume Mapping
```yaml
# config/deploy.yml
volumes:
  - "/data/livekit-admin/storage:/rails/storage"
  - "/data/livekit-admin/db:/rails/db"
  - "/data/livekit-admin/videos:/rails/public/videos"
```

## CI/CD Pipeline Stages

### 1. Build Stage
- **Trigger**: Git push to main branch
- **Actions**:
  - Clone repository
  - Build Docker image with multi-stage build
  - Tag with commit SHA and 'latest'
  - Push to Docker Hub registry

### 2. Deploy Stage
- **Trigger**: Successful build
- **Actions**:
  - Pull latest image on Hetzner server
  - Stop old container gracefully
  - Start new container with volume mounts
  - Run database migrations
  - Health check verification

### 3. Post-Deploy
- **Actions**:
  - Smoke tests via GitHub Actions
  - Monitor container logs
  - Alert on failures

## Schema Caching Issue Resolution

### Problem
Rails models with ActiveRecord scopes load at boot time, causing "table not found" errors when database isn't ready.

### Solution
Wrap all scopes with `table_exists?` checks:

```ruby
# Safe scope definition
scope :recent, -> { table_exists? ? order(created_at: :desc) : none }
```

## Clean Build Process

### Complete Docker Cleanup
```bash
# Local cleanup
docker system prune -af --volumes
docker builder prune -af

# Remote server cleanup
ssh deploy@server 'docker system prune -af --volumes'

# Fresh build without cache
DOCKER_BUILD_NO_CACHE=1 kamal deploy
```

## Deployment Commands

### Standard Deploy
```bash
git add -A
git commit -m "Your changes"
kamal deploy
```

### Emergency Rollback
```bash
kamal rollback
```

### Debug Container
```bash
kamal app exec 'bash'
kamal app logs --lines 100
```

## Security Considerations

1. **Never run as root** in production containers
2. **Use numeric UIDs** for better compatibility
3. **Minimal base images** (ruby-slim)
4. **Read-only root filesystem** where possible
5. **Volume permissions** should be restrictive (755 for directories, 644 for files)

## Monitoring & Alerts

### Health Checks
- `/up` endpoint for container health
- Database connectivity check
- Volume write permission test

### Smoke Tests
- Automated via GitHub Actions
- Tests critical endpoints
- Verifies asset pipeline
- Checks database migrations

## Troubleshooting

### Permission Denied Errors
1. Verify UID alignment: `kamal app exec 'id'`
2. Check host volume ownership: `ssh deploy@server 'ls -la /data/livekit-admin/'`
3. Fix if needed: `ssh deploy@server 'sudo chown -R deploy:deploy /data/livekit-admin/'`

### Container Restart Loop
1. Check logs: `kamal app logs --lines 50`
2. Common causes:
   - Permission issues (see above)
   - Missing environment variables
   - Database connection failures
   - Invalid secrets

### Schema Caching Errors
1. Ensure all model scopes use `table_exists?` guards
2. Run migrations: `kamal app exec 'bin/rails db:migrate'`
3. Restart container: `kamal app restart`

## Best Practices

1. **Always test locally** before deploying
2. **Use staging environment** for validation
3. **Monitor deployment logs** in real-time
4. **Keep volumes backed up** regularly
5. **Document environment variables** in .env.example
6. **Version lock dependencies** in Gemfile.lock
7. **Use health checks** for zero-downtime deploys
8. **Implement rollback strategy** for emergencies

## Future Improvements

1. **Implement Blue-Green Deployments** for zero-downtime
2. **Add Automated Backup** for volumes
3. **Integrate APM** (Application Performance Monitoring)
4. **Add Container Scanning** for vulnerabilities
5. **Implement GitOps** with ArgoCD or Flux