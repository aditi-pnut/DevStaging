#!/bin/bash

set -e

echo "🚀 Starting deployment process..."

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 878239241975.dkr.ecr.us-east-2.amazonaws.com

# Navigate to project directory
echo "📂 Changing to project directory..."
cd /home/ubuntu/pnut-code/

# Generate the latest tags for all services
echo "🧬 Fetching latest image tags from ECR..."
./generate_tag.sh

# Stop existing services
echo "🛑 Stopping running containers..."
docker compose down

# Pull the latest images
echo "📥 Pulling updated images from ECR..."
docker compose --env-file .env pull --ignore-pull-failures

# Start services with updated images
echo "🚢 Starting containers using Compose..."
docker compose --env-file .env up -d

# Tag images with timestamp and prune older ones
echo "🏷️ Tagging latest images and removing older ones..."
python3 tag.py

# Final cleanup
echo "🧹 Pruning unused containers, networks, and images..."
docker system prune -f

echo "✅ Deployment completed successfully!"
