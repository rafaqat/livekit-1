require 'jwt'
require 'httparty'

class LivekitService
  include HTTParty
  
  API_KEY = ENV.fetch('LIVEKIT_API_KEY') { raise 'LIVEKIT_API_KEY is not set' }
  API_SECRET = ENV.fetch('LIVEKIT_API_SECRET') { raise 'LIVEKIT_API_SECRET is not set' }
  SERVER_URL = ENV.fetch('LIVEKIT_SERVER_URL') { raise 'LIVEKIT_SERVER_URL is not set' }
  WS_URL = ENV.fetch('LIVEKIT_WS_URL') { raise 'LIVEKIT_WS_URL is not set' }
  
  base_uri SERVER_URL
  
  class << self
    # Generate JWT token for API access
    def generate_token(grants = {})
      payload = {
        iss: API_KEY,
        nbf: Time.now.to_i - 60,
        exp: Time.now.to_i + 3600,
        **grants
      }
      
      JWT.encode(payload, API_SECRET, 'HS256')
    end
    
    # Room Management
    def create_room(name:, empty_timeout: 300, max_participants: 20, metadata: nil)
      token = generate_token(video: { roomCreate: true })
      
      response = post('/twirp/livekit.RoomService/CreateRoom',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: {
          name: name,
          emptyTimeout: empty_timeout,
          maxParticipants: max_participants,
          metadata: metadata
        }.compact.to_json
      )
      
      parse_response(response)
    end
    
    def list_rooms
      token = generate_token(video: { roomList: true })
      
      response = post('/twirp/livekit.RoomService/ListRooms',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: '{}'
      )
      
      result = parse_response(response)
      result['rooms'] || []
    end
    
    def get_room(room_name)
      list_rooms.find { |room| room['name'] == room_name }
    end
    
    def delete_room(room_name)
      token = generate_token(video: { roomCreate: true })
      
      response = post('/twirp/livekit.RoomService/DeleteRoom',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { room: room_name }.to_json
      )
      
      parse_response(response)
    end
    
    def update_room_metadata(room_name, metadata)
      token = generate_token(video: { roomAdmin: true, room: room_name })
      
      response = post('/twirp/livekit.RoomService/UpdateRoomMetadata',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { room: room_name, metadata: metadata }.to_json
      )
      
      parse_response(response)
    end
    
    # Participant Management
    def list_participants(room_name)
      token = generate_token(video: { roomAdmin: true, room: room_name })
      
      response = post('/twirp/livekit.RoomService/ListParticipants',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { room: room_name }.to_json
      )
      
      result = parse_response(response)
      result['participants'] || []
    end
    
    def get_participant(room_name, identity)
      token = generate_token(video: { roomAdmin: true, room: room_name })
      
      response = post('/twirp/livekit.RoomService/GetParticipant',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { room: room_name, identity: identity }.to_json
      )
      
      parse_response(response)
    end
    
    def remove_participant(room_name, identity)
      token = generate_token(video: { roomAdmin: true, room: room_name })
      
      response = post('/twirp/livekit.RoomService/RemoveParticipant',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { room: room_name, identity: identity }.to_json
      )
      
      parse_response(response)
    end
    
    def mute_track(room_name, identity, track_sid, muted)
      token = generate_token(video: { roomAdmin: true, room: room_name })
      
      response = post('/twirp/livekit.RoomService/MutePublishedTrack',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: {
          room: room_name,
          identity: identity,
          trackSid: track_sid,
          muted: muted
        }.to_json
      )
      
      parse_response(response)
    end
    
    def update_participant(room_name, identity, metadata: nil, permission: nil)
      token = generate_token(video: { roomAdmin: true, room: room_name })
      
      body = { room: room_name, identity: identity }
      body[:metadata] = metadata if metadata
      body[:permission] = permission if permission
      
      response = post('/twirp/livekit.RoomService/UpdateParticipant',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      parse_response(response)
    end
    
    # Access Token Generation
    def create_access_token(room_name:, identity:, name: nil, metadata: nil, can_publish: true, can_subscribe: true)
      grants = {
        sub: identity,
        video: {
          room: room_name,
          roomJoin: true,
          canPublish: can_publish,
          canSubscribe: can_subscribe
        },
        name: name || identity,
        metadata: metadata
      }.compact
      
      generate_token(grants)
    end
    
    # Send data to room
    def send_data(room_name, data, kind = 'RELIABLE', destination_sids = [])
      token = generate_token(video: { roomAdmin: true, room: room_name })
      
      response = post('/twirp/livekit.RoomService/SendData',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: {
          room: room_name,
          data: Base64.encode64(data),
          kind: kind,
          destinationSids: destination_sids
        }.to_json
      )
      
      parse_response(response)
    end
    
    # Recording and Egress Management
    def start_room_composite_egress(room_name:, file_outputs: nil, stream_outputs: nil, segment_outputs: nil, layout: 'speaker-dark', audio_only: false)
      token = generate_token(video: { roomRecord: true })
      
      body = {
        roomName: room_name,
        layout: layout,
        audioOnly: audio_only
      }
      
      body[:file] = file_outputs if file_outputs
      body[:stream] = stream_outputs if stream_outputs
      body[:segments] = segment_outputs if segment_outputs
      
      response = post('/twirp/livekit.Egress/StartRoomCompositeEgress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      parse_response(response)
    end
    
    def start_track_composite_egress(room_name:, audio_track_id: nil, video_track_id: nil, file_outputs: nil, stream_outputs: nil)
      token = generate_token(video: { roomRecord: true })
      
      body = {
        roomName: room_name
      }
      
      body[:audioTrackId] = audio_track_id if audio_track_id
      body[:videoTrackId] = video_track_id if video_track_id
      body[:file] = file_outputs if file_outputs
      body[:stream] = stream_outputs if stream_outputs
      
      response = post('/twirp/livekit.Egress/StartTrackCompositeEgress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      parse_response(response)
    end
    
    def start_track_egress(room_name:, track_id:, file_output: nil, stream_output: nil)
      token = generate_token(video: { roomRecord: true })
      
      body = {
        roomName: room_name,
        trackId: track_id
      }
      
      body[:file] = file_output if file_output
      body[:stream] = stream_output if stream_output
      
      response = post('/twirp/livekit.Egress/StartTrackEgress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      parse_response(response)
    end
    
    def list_egress(room_name: nil, egress_id: nil)
      token = generate_token(video: { roomRecord: true })
      
      body = {}
      body[:roomName] = room_name if room_name
      body[:egressId] = egress_id if egress_id
      
      response = post('/twirp/livekit.Egress/ListEgress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      result = parse_response(response)
      result['items'] || []
    end
    
    def stop_egress(egress_id)
      token = generate_token(video: { roomRecord: true })
      
      response = post('/twirp/livekit.Egress/StopEgress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { egressId: egress_id }.to_json
      )
      
      parse_response(response)
    end
    
    def update_layout(egress_id, layout)
      token = generate_token(video: { roomRecord: true })
      
      response = post('/twirp/livekit.Egress/UpdateLayout',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { egressId: egress_id, layout: layout }.to_json
      )
      
      parse_response(response)
    end
    
    def update_stream(egress_id, add_output_urls: [], remove_output_urls: [])
      token = generate_token(video: { roomRecord: true })
      
      response = post('/twirp/livekit.Egress/UpdateStream',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: {
          egressId: egress_id,
          addOutputUrls: add_output_urls,
          removeOutputUrls: remove_output_urls
        }.to_json
      )
      
      parse_response(response)
    end
    
    # Ingress Management
    def create_ingress(name:, room_name:, participant_identity:, participant_name: nil, 
                      stream_key: nil, url: nil, input_type: 'RTMP_INPUT',
                      audio: nil, video: nil, enable_transcoding: nil, enabled: nil)
      token = generate_token(video: { ingressAdmin: true })
      
      body = {
        name: name,
        roomName: room_name,
        participantIdentity: participant_identity,
        participantName: participant_name || participant_identity,
        inputType: input_type
      }
      
      # Add stream key for RTMP/WHIP inputs
      body[:streamKey] = stream_key if stream_key && input_type != 'URL_INPUT'
      
      # Add URL for URL_INPUT type
      body[:url] = url if url && input_type == 'URL_INPUT'
      
      # Add optional audio/video configuration
      body[:audio] = audio if audio
      body[:video] = video if video
      
      # Add transcoding settings
      body[:enableTranscoding] = enable_transcoding unless enable_transcoding.nil?
      
      # Add enabled flag
      body[:enabled] = enabled unless enabled.nil?
      
      response = post('/twirp/livekit.Ingress/CreateIngress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      parse_response(response)
    end
    
    def list_ingress(room_name: nil, ingress_id: nil)
      token = generate_token(video: { ingressAdmin: true })
      
      body = {}
      body[:roomName] = room_name if room_name
      body[:ingressId] = ingress_id if ingress_id
      
      response = post('/twirp/livekit.Ingress/ListIngress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      result = parse_response(response)
      result['items'] || []
    end
    
    def update_ingress(ingress_id, name: nil, room_name: nil, participant_identity: nil, participant_name: nil)
      token = generate_token(video: { ingressAdmin: true })
      
      body = { ingressId: ingress_id }
      body[:name] = name if name
      body[:roomName] = room_name if room_name
      body[:participantIdentity] = participant_identity if participant_identity
      body[:participantName] = participant_name if participant_name
      
      response = post('/twirp/livekit.Ingress/UpdateIngress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )
      
      parse_response(response)
    end
    
    def delete_ingress(ingress_id)
      token = generate_token(video: { ingressAdmin: true })
      
      response = post('/twirp/livekit.Ingress/DeleteIngress',
        headers: {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json'
        },
        body: { ingressId: ingress_id }.to_json
      )
      
      parse_response(response)
    end
    
    # Statistics and Health
    def server_info
      token = generate_token(video: { roomList: true })
      
      # This is a placeholder - LiveKit doesn't have a direct server info endpoint
      # We can derive some info from room list
      rooms = list_rooms
      
      {
        server_url: SERVER_URL,
        ws_url: WS_URL,
        total_rooms: rooms.size,
        total_participants: rooms.sum { |r| r['num_participants'] || 0 },
        rooms_summary: rooms.map { |r| 
          {
            name: r['name'],
            participants: r['num_participants'],
            max_participants: r['max_participants']
          }
        }
      }
    end
    
    private
    
    def parse_response(response)
      if response.success?
        response.parsed_response || {}
      else
        raise "LiveKit API Error: #{response.code} - #{response.body}"
      end
    end
  end
end
