#!/bin/bash
set -e

echo "========================================="
echo "COMPLETE CLEAN SLATE DEPLOYMENT"
echo "========================================="
echo

# Step 1: Clean all local Docker resources
echo "Step 1: Cleaning all local Docker resources..."
echo "----------------------------------------"
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm -f $(docker ps -aq) 2>/dev/null || true
docker rmi -f $(docker images -q) 2>/dev/null || true
docker volume rm $(docker volume ls -q) 2>/dev/null || true
docker network prune -f 2>/dev/null || true
docker system prune -af --volumes 2>/dev/null || true
echo "✅ Local Docker cleaned"
echo

# Step 2: Remove all Docker builders
echo "Step 2: Removing all Docker builders..."
echo "----------------------------------------"
docker buildx rm --all-inactive -f 2>/dev/null || true
docker buildx rm kamal-local-docker-container 2>/dev/null || true
docker buildx rm kamal-multiarch 2>/dev/null || true
docker buildx rm kamal-native-remote 2>/dev/null || true
docker buildx rm kamal-native-cached 2>/dev/null || true
docker buildx rm kamal-super-clean 2>/dev/null || true
docker buildx rm kamal-fresh-builder 2>/dev/null || true
docker buildx prune -af 2>/dev/null || true
echo "✅ Docker builders removed"
echo

# Step 3: Clean Kamal temporary files
echo "Step 3: Cleaning Kamal temporary files..."
echo "----------------------------------------"
rm -rf /var/folders/yh/_g4gjy4905v4tc4rswpfssvh0000gn/T/kamal-clones/ 2>/dev/null || true
rm -rf /tmp/kamal-* 2>/dev/null || true
echo "✅ Kamal temp files cleaned"
echo

# Step 4: Clean remote Docker resources on Hetzner
echo "Step 4: Cleaning remote Docker resources..."
echo "----------------------------------------"
kamal app stop 2>/dev/null || true
sleep 2
ssh root@157.180.124.104 "docker stop \$(docker ps -aq) 2>/dev/null || true"
ssh root@157.180.124.104 "docker rm -f \$(docker ps -aq) 2>/dev/null || true"
ssh root@157.180.124.104 "docker rmi -f \$(docker images -q) 2>/dev/null || true"
ssh root@157.180.124.104 "docker volume rm \$(docker volume ls -q) 2>/dev/null || true"
ssh root@157.180.124.104 "docker system prune -af --volumes"
ssh root@157.180.124.104 "rm -rf /data/livekit-admin/*"
ssh root@157.180.124.104 "rm -rf .kamal"
echo "✅ Remote Docker cleaned"
echo

# Step 5: Remove images from Docker Hub
echo "Step 5: Removing images from Docker Hub..."
echo "----------------------------------------"
# Note: This requires Docker Hub API access with delete permissions
# For now, we'll just note this step
echo "⚠️  Manual step: Remove images from Docker Hub if needed"
echo

# Step 6: Create fresh buildx builder
echo "Step 6: Creating fresh buildx builder..."
echo "----------------------------------------"
docker buildx create --driver docker-container --name kamal-clean-deploy --use
docker buildx inspect --bootstrap
echo "✅ Fresh builder created"
echo

echo "========================================="
echo "CLEAN SLATE PREPARATION COMPLETE"
echo "========================================="
echo
echo "Starting fresh deployment..."
echo

# Step 7: Deploy from scratch (Kamal hooks will handle volume setup)
kamal deploy

echo
echo "========================================="
echo "DEPLOYMENT COMPLETE"
echo "========================================="
