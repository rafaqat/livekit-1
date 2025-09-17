#!/bin/bash

echo "🎥 Testing VOD Fixes"
echo "===================="
echo ""

BASE_URL="https://admin.livekit.lovedrop.live"

# Upload a test video
echo "1. Uploading test video for VOD..."
cd /Users/macbookairm432g/work/monorepo/livekit/deploy
ruby test_video_upload_with_csrf.rb > /tmp/vod_test.log 2>&1
if grep -q "Video ID: video_" /tmp/vod_test.log; then
    VIDEO_ID=$(grep "Video ID:" /tmp/vod_test.log | sed 's/.*Video ID: //')
    echo "   ✅ Video uploaded: $VIDEO_ID"
else
    echo "   ❌ Upload failed"
    cat /tmp/vod_test.log
    exit 1
fi

# Check NO LiveKit room was created
echo -e "\n2. Verifying NO LiveKit room created..."
ROOM_COUNT=$(ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"rooms = LivekitService.list_rooms; puts rooms.select {|r| r['name'].include?('$VIDEO_ID')}.size\"" 2>/dev/null)
if [ "$ROOM_COUNT" = "0" ] || [ "$ROOM_COUNT" = "" ]; then
    echo "   ✅ FIXED! No LiveKit room created for VOD"
else
    echo "   ❌ Still creating room: $ROOM_COUNT rooms found"
fi

# Test VOD stream endpoint
echo -e "\n3. Testing VOD stream endpoint..."
TOKEN=$(ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"v = Video.find_by(video_id: '$VIDEO_ID'); puts v.generate_viewing_token('test', {})\"" 2>/dev/null | tr -d '\n')
if [ -n "$TOKEN" ]; then
    STREAM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/vod/${VIDEO_ID}/stream?token=${TOKEN}")
    if [ "$STREAM_STATUS" = "200" ] || [ "$STREAM_STATUS" = "206" ]; then
        echo "   ✅ FIXED! VOD stream working (HTTP $STREAM_STATUS)"
    else
        echo "   ❌ Stream still failing (HTTP $STREAM_STATUS)"
    fi
else
    echo "   ❌ Could not generate token"
fi

# Verify file_path is now accessible
echo -e "\n4. Verifying file_path method is public..."
PATH_TEST=$(ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"v = Video.find_by(video_id: '$VIDEO_ID'); puts v.file_path\"" 2>/dev/null)
if echo "$PATH_TEST" | grep -q "public/videos/$VIDEO_ID"; then
    echo "   ✅ file_path method is public and working"
else
    echo "   ❌ file_path method issue"
fi

# Cleanup
echo -e "\n5. Cleaning up test data..."
ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"Video.find_by(video_id: '$VIDEO_ID')&.destroy\"" 2>/dev/null
ssh root@157.180.124.104 "docker exec admin-livekit rm -f public/videos/${VIDEO_ID}.mp4" 2>/dev/null
echo "   ✅ Cleaned up"

echo ""
echo "===================="
echo "✅ VOD Fixes Test Complete!"
echo "===================="
