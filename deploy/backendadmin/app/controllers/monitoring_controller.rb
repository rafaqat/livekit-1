class MonitoringController < ApplicationController
  def index
    @server_info = LivekitService.server_info
    @rooms = LivekitService.list_rooms
    @egresses = LivekitService.list_egress
    @ingresses = LivekitService.list_ingress
    
    # Calculate statistics
    @stats = calculate_statistics
    
    # Get room usage over time (would need to be stored/tracked)
    @room_history = get_room_history
    
    # Performance metrics
    @performance = calculate_performance_metrics
  rescue => e
    @error = e.message
    @stats = default_stats
    @performance = default_performance
  end
  
  def health
    # Health check endpoint
    begin
      rooms = LivekitService.list_rooms
      render json: {
        status: 'healthy',
        server: ENV['LIVEKIT_SERVER_URL'],
        rooms: rooms.size,
        timestamp: Time.now.to_i
      }
    rescue => e
      render json: {
        status: 'unhealthy',
        error: e.message,
        timestamp: Time.now.to_i
      }, status: :service_unavailable
    end
  end
  
  def metrics
    # Prometheus-style metrics endpoint
    rooms = LivekitService.list_rooms
    egresses = LivekitService.list_egress
    ingresses = LivekitService.list_ingress
    
    metrics_text = <<~METRICS
      # HELP livekit_rooms_total Total number of active rooms
      # TYPE livekit_rooms_total gauge
      livekit_rooms_total #{rooms.size}
      
      # HELP livekit_participants_total Total number of participants across all rooms
      # TYPE livekit_participants_total gauge
      livekit_participants_total #{rooms.sum { |r| r['num_participants'] || 0 }}
      
      # HELP livekit_publishers_total Total number of publishers across all rooms
      # TYPE livekit_publishers_total gauge
      livekit_publishers_total #{rooms.sum { |r| r['num_publishers'] || 0 }}
      
      # HELP livekit_egress_active Number of active egress sessions
      # TYPE livekit_egress_active gauge
      livekit_egress_active #{egresses.select { |e| e['status'] == 'EGRESS_ACTIVE' }.size}
      
      # HELP livekit_ingress_active Number of active ingress sessions
      # TYPE livekit_ingress_active gauge
      livekit_ingress_active #{ingresses.select { |i| i['state'] == 'ENDPOINT_PUBLISHING' }.size}
      
      # HELP livekit_room_capacity Average room capacity usage percentage
      # TYPE livekit_room_capacity gauge
      livekit_room_capacity #{calculate_capacity_usage(rooms)}
    METRICS
    
    render plain: metrics_text, content_type: 'text/plain'
  rescue => e
    render plain: "# Error generating metrics: #{e.message}", status: :internal_server_error
  end
  
  def logs
    # Would integrate with actual log aggregation service
    @logs = []
    
    # Placeholder for log retrieval
    # In production, this would connect to your logging system
    render json: {
      logs: @logs,
      message: "Log aggregation not yet configured"
    }
  end

  def jobs
    # Solid Queue jobs and scheduled VOD/broadcast state overview
    recurring_tasks = safe_fetch { SolidQueue::RecurringTask.order(:key).limit(100) }
    scheduled_execs = safe_fetch { SolidQueue::ScheduledExecution.order(:scheduled_at).limit(100) }
    ready_execs     = safe_fetch { SolidQueue::ReadyExecution.order(:priority).limit(100) }
    failed_execs    = safe_fetch { SolidQueue::FailedExecution.order(finished_at: :desc).limit(50) }

    scheduled_videos = Video.streaming_mode_scheduled.order(:scheduled_start_at).limit(100).map do |v|
      {
        video_id: v.video_id,
        title: v.title,
        scheduled_start_at: v.scheduled_start_at,
        scheduled_end_at: v.scheduled_end_at,
        streaming_active: v.streaming_active,
        ingress_state: v.ingress_state
      }
    end

    broadcast_videos = Video.streaming_mode_live_broadcast.order(updated_at: :desc).limit(100).map do |v|
      {
        video_id: v.video_id,
        title: v.title,
        streaming_active: v.streaming_active,
        ingress_state: v.ingress_state,
        ingress_id: v.ingress_id,
        streaming_status: v.streaming_status
      }
    end

    render json: {
      solid_queue: {
        recurring_tasks: Array(recurring_tasks).map { |t| { key: t.key, schedule: t.schedule, static: t.static } },
        scheduled_executions: Array(scheduled_execs).map { |e| { id: e.id, class_name: e.job.class_name, scheduled_at: e.scheduled_at } rescue nil }.compact,
        ready_executions: Array(ready_execs).map { |e| { id: e.id, class_name: e.job.class_name, queue_name: e.queue_name } rescue nil }.compact,
        failed_executions: Array(failed_execs).map { |e| { id: e.id, class_name: e.job.class_name, error: e.error, finished_at: e.finished_at } rescue nil }.compact
      },
      videos: {
        scheduled: scheduled_videos,
        broadcast: broadcast_videos
      },
      timestamp: Time.current
    }
  end
  
  private
  
  def calculate_statistics
    rooms = @rooms || []
    participants = rooms.sum { |r| r['num_participants'] || 0 }
    publishers = rooms.sum { |r| r['num_publishers'] || 0 }
    
    {
      total_rooms: rooms.size,
      active_rooms: rooms.select { |r| (r['num_participants'] || 0) > 0 }.size,
      total_participants: participants,
      total_publishers: publishers,
      avg_participants_per_room: rooms.size > 0 ? (participants.to_f / rooms.size).round(1) : 0,
      max_participants_in_room: rooms.map { |r| r['num_participants'] || 0 }.max || 0,
      total_capacity: rooms.sum { |r| r['max_participants'] || 0 },
      capacity_usage: calculate_capacity_usage(rooms),
      recording_sessions: (@egresses || []).select { |e| e['status'] == 'EGRESS_ACTIVE' }.size,
      streaming_inputs: (@ingresses || []).select { |i| i['state'] == 'ENDPOINT_PUBLISHING' }.size
    }
  end
  
  def calculate_capacity_usage(rooms)
    total_capacity = rooms.sum { |r| r['max_participants'] || 0 }
    total_participants = rooms.sum { |r| r['num_participants'] || 0 }
    
    return 0 if total_capacity == 0
    ((total_participants.to_f / total_capacity) * 100).round(1)
  end
  
  def default_stats
    {
      total_rooms: 0,
      active_rooms: 0,
      total_participants: 0,
      total_publishers: 0,
      avg_participants_per_room: 0,
      max_participants_in_room: 0,
      total_capacity: 0,
      capacity_usage: 0,
      recording_sessions: 0,
      streaming_inputs: 0
    }
  end
  
  def get_room_history
    # This would need to be tracked and stored over time
    # For now, return sample data structure
    {
      labels: (0..23).map { |h| "#{h}:00" },
      rooms: Array.new(24) { rand(0..10) },
      participants: Array.new(24) { rand(0..50) }
    }
  end
  
  def calculate_performance_metrics
    # These would come from actual monitoring
    {
      cpu_usage: rand(10..50),
      memory_usage: rand(20..60),
      bandwidth_in: rand(100..500),
      bandwidth_out: rand(200..800),
      latency: rand(10..50),
      packet_loss: rand(0.0..0.5).round(2)
    }
  end
  
  def default_performance
    {
      cpu_usage: 0,
      memory_usage: 0,
      bandwidth_in: 0,
      bandwidth_out: 0,
      latency: 0,
      packet_loss: 0
    }
  end

  def safe_fetch
    yield
  rescue NameError
    []
  end
end
