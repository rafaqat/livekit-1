require 'sidekiq'
require 'uri'

# Redis configuration for Sidekiq
# Use container name:port when running in Docker network
redis_addr = ENV['LIVEKIT_REDIS_ADDR'] || 'livekit-server-redis_auth:6379'
redis_password = ENV['LIVEKIT_REDIS_PASSWORD'] || 'QOYpcauZW0LHBXStJMbEmNLlrvY+LBRo/fR3ExxZwSc='

# Build URL with password embedded
redis_url = "redis://:#{URI.encode_www_form_component(redis_password)}@#{redis_addr}/1"

redis_config = {
  url: redis_url  # Use database 1 for Sidekiq
}

Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end