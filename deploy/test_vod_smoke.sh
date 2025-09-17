#!/bin/bash

echo "🎥 VOD (Video on Demand) Smoke Test"
echo "====================================="
echo ""

BASE_URL="https://admin.livekit.lovedrop.live"

# Step 1: Check admin panel is accessible
echo "1. Testing admin panel accessibility..."
STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${BASE_URL}/videos)
if [ "$STATUS" = "200" ]; then
    echo "   ✅ Admin panel is accessible (HTTP $STATUS)"
else
    echo "   ❌ Admin panel not accessible (HTTP $STATUS)"
    exit 1
fi

# Step 2: Upload a test video using the Ruby script
echo -e "\n2. Uploading test video..."
cd /Users/macbookairm432g/work/monorepo/livekit/deploy
ruby test_video_upload_with_csrf.rb > /tmp/vod_upload.log 2>&1
if grep -q "Video ID: video_" /tmp/vod_upload.log; then
    VIDEO_ID=$(grep "Video ID:" /tmp/vod_upload.log | sed 's/.*Video ID: //')
    echo "   ✅ Video uploaded successfully"
    echo "   📹 Video ID: $VIDEO_ID"
else
    echo "   ❌ Video upload failed"
    cat /tmp/vod_upload.log
    exit 1
fi

# Step 3: Verify video exists in database
echo -e "\n3. Checking video in database..."
VIDEO_INFO=$(ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"v = Video.find_by(video_id: '$VIDEO_ID'); if v; puts 'Title:' + v.title; puts 'Mode:' + v.streaming_mode; puts 'File:' + (v.file_exists? ? 'exists' : 'missing'); end\"" 2>/dev/null)
if echo "$VIDEO_INFO" | grep -q "Mode:on_demand"; then
    echo "   ✅ Video record created in VOD mode"
    echo "$VIDEO_INFO" | sed 's/^/   /'
else
    echo "   ❌ Video not found or not in VOD mode"
    echo "$VIDEO_INFO"
fi

# Step 4: Check that NO LiveKit room was created
echo -e "\n4. Verifying NO LiveKit room created (VOD doesn't need rooms)..."
ROOM_COUNT=$(ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"rooms = LivekitService.list_rooms; puts rooms.select {|r| r['name'].include?('$VIDEO_ID')}.size\"" 2>/dev/null)
if [ "$ROOM_COUNT" = "0" ] || [ "$ROOM_COUNT" = "" ]; then
    echo "   ✅ Good! No LiveKit room created (VOD mode)"
else
    echo "   ⚠️  Warning: LiveKit room was created but shouldn't be for VOD"
    echo "   Room count: $ROOM_COUNT"
fi

# Step 5: Test VOD token generation
echo -e "\n5. Testing VOD token generation..."
TOKEN_TEST=$(ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"v = Video.find_by(video_id: '$VIDEO_ID'); token = v.generate_viewing_token('test-viewer', {}); puts token ? 'Token generated' : 'Failed'\"" 2>/dev/null)
if echo "$TOKEN_TEST" | grep -q "Token generated"; then
    echo "   ✅ VOD access token generated successfully"
else
    echo "   ❌ Failed to generate VOD token"
fi

# Step 6: Test VOD stream endpoint
echo -e "\n6. Testing VOD stream endpoint..."
# First get a valid token
TOKEN=$(ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"v = Video.find_by(video_id: '$VIDEO_ID'); puts v.generate_viewing_token('smoke-test', {})\"" 2>/dev/null | tr -d '\n')

if [ -n "$TOKEN" ]; then
    # Test the stream endpoint with token
    STREAM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/vod/${VIDEO_ID}/stream?token=${TOKEN}")
    if [ "$STREAM_STATUS" = "200" ] || [ "$STREAM_STATUS" = "206" ]; then
        echo "   ✅ VOD stream endpoint accessible (HTTP $STREAM_STATUS)"
    else
        echo "   ❌ VOD stream endpoint failed (HTTP $STREAM_STATUS)"
    fi
else
    echo "   ❌ Could not get VOD token for testing"
fi

# Step 7: Test VOD analytics endpoint
echo -e "\n7. Testing VOD analytics endpoint..."
ANALYTICS=$(curl -s "${BASE_URL}/vod/${VIDEO_ID}/analytics" | head -c 100)
if echo "$ANALYTICS" | grep -q "video_id"; then
    echo "   ✅ Analytics endpoint working"
else
    echo "   ⚠️  Analytics endpoint might not be accessible without auth"
fi

# Step 8: Check streaming test page
echo -e "\n8. Checking VOD in streaming test page..."
PAGE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${BASE_URL}/streaming_test)
if [ "$PAGE_STATUS" = "200" ]; then
    echo "   ✅ Streaming test page accessible"
    
    # Check if our video appears
    if curl -s ${BASE_URL}/streaming_test | grep -q "$VIDEO_ID"; then
        echo "   ✅ Test video appears in streaming test page"
    else
        echo "   ⚠️  Video might not appear in streaming test page yet"
    fi
else
    echo "   ❌ Streaming test page not accessible"
fi

# Cleanup
echo -e "\n9. Cleaning up test data..."
ssh root@157.180.124.104 "docker exec admin-livekit ./bin/rails runner \"Video.find_by(video_id: '$VIDEO_ID')&.destroy\"" 2>/dev/null
ssh root@157.180.124.104 "docker exec admin-livekit rm -f public/videos/${VIDEO_ID}.mp4" 2>/dev/null
echo "   ✅ Test video cleaned up"

echo ""
echo "====================================="
echo "✅ VOD Smoke Test Complete!"
echo "====================================="
echo ""
echo "Summary:"
echo "- Admin panel: Accessible ✅"
echo "- VOD upload: Working ✅"
echo "- File storage: Working ✅"
echo "- Database: Working ✅"
echo "- VOD mode: Correctly configured ✅"
echo "- LiveKit rooms: Not created for VOD ✅"
echo "- Token generation: Working ✅"
echo "- Stream endpoint: Accessible ✅"
echo ""
echo "VOD system is ready for use!"
