# LiveKit Admin Backend

Production-oriented notes for operating the VOD + broadcast backend.

## Requirements

- Ruby: containerized (Kamal builds the app image; local Ruby not required)
- Docker on deploy host(s)
- ffprobe (via ffmpeg) available in runtime image/host for accurate duration extraction

## Configuration

Environment variables (set via Kamal `config/deploy.yml` and `.kamal/secrets`):

- `RAILS_MASTER_KEY`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `LIVEKIT_SERVER_URL`
- `LIVEKIT_WS_URL`
- Optional: `ASSET_BASE_URL` for public videos base URL

Persistent volumes (see `config/deploy.yml`):

- `/data/livekit-admin/storage:/rails/storage`
- `/data/livekit-admin/db:/rails/db`
- `/data/livekit-admin/videos:/rails/public/videos`

## Database

Run migrations after deploy:

```bash
bin/kamal app exec "bin/rails db:migrate"
```

## Background Jobs (Solid Queue)

- Recurring jobs (`IngressMonitorJob`, `ScheduledStreamJob`) are configured in `config/recurring.yml` (every minute).
- To run jobs inside Puma, set `SOLID_QUEUE_IN_PUMA=1` (enabled via Puma plugin).
- Or run a separate worker:

```bash
bin/kamal app exec --reuse "bundle exec solid_queue start"
```

## ffprobe

`ffprobe` is used by `Video#extract_video_duration` for precise durations.

- Debian/Ubuntu: `apt-get update && apt-get install -y ffmpeg`
- Alpine: `apk add --no-cache ffmpeg`

## Deployment (Kamal)

Build and deploy the image to the configured server(s):

```bash
bin/kamal deploy
```

## Smoke Test

Validate JWT token + session lifecycle:

```bash
bin/rails runner script/smoke_vod.rb
```

This creates a temporary VOD video record, starts/ends a viewing session, and verifies token contents.
