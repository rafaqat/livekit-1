#!/bin/bash

# Create a test MP4 video file using FFmpeg (if available)
# This creates a simple 10-second test pattern video

OUTPUT_FILE="test_video.mp4"

echo "Creating test video file..."

# Check if ffmpeg is available
if command -v ffmpeg &> /dev/null; then
    # Create a 10-second test video with audio
    ffmpeg -f lavfi -i testsrc=duration=10:size=1920x1080:rate=30 \
           -f lavfi -i sine=frequency=1000:duration=10 \
           -c:v libx264 -preset fast -crf 22 \
           -c:a aac -b:a 128k \
           -pix_fmt yuv420p \
           -y $OUTPUT_FILE
    
    echo "✅ Test video created: $OUTPUT_FILE"
    echo "   Duration: 10 seconds"
    echo "   Resolution: 1920x1080"
    echo "   Framerate: 30fps"
    echo "   Audio: AAC 128k"
    
    # Show file info
    ls -lh $OUTPUT_FILE
else
    echo "⚠️  FFmpeg not found. Creating placeholder file..."
    # Create a small placeholder file
    echo "This would be an MP4 video file" > $OUTPUT_FILE
    echo "✅ Placeholder file created: $OUTPUT_FILE"
    echo "   Note: Install FFmpeg to create actual test videos"
    echo "   brew install ffmpeg"
fi

echo ""
echo "Next steps:"
echo "1. Go to https://admin.livekit.lovedrop.live/videos/new"
echo "2. Upload this file: $OUTPUT_FILE"
echo "3. The video will automatically start streaming via URL Input"
echo "4. Get the iOS token from the video details page"
echo "5. Connect your iOS app using the token and WebSocket URL"