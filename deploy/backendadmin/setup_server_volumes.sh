#!/bin/bash
set -e

echo "========================================="
echo "SETTING UP SERVER VOLUME PERMISSIONS"
echo "========================================="
echo

# Server configuration
SERVER_IP="157.180.124.104"
SERVER_USER="root"

echo "Step 1: Creating volume directories on server..."
echo "----------------------------------------"
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p /data/livekit-admin/storage /data/livekit-admin/db /data/livekit-admin/videos"
echo "✅ Directories created"
echo

echo "Step 2: Setting proper ownership (UID 1000)..."
echo "----------------------------------------"
# UID 1000 matches the rails user in our Docker container
ssh ${SERVER_USER}@${SERVER_IP} "chown -R 1000:1000 /data/livekit-admin/"
echo "✅ Ownership set to UID 1000"
echo

echo "Step 3: Verifying permissions..."
echo "----------------------------------------"
ssh ${SERVER_USER}@${SERVER_IP} "ls -la /data/livekit-admin/"
echo "✅ Permissions verified"
echo

echo "========================================="
echo "SERVER VOLUME SETUP COMPLETE"
echo "========================================="
echo "You can now run 'kamal deploy' safely"
echo