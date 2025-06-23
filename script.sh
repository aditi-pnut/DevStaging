#!/bin/bash

# Enable error handling
set -e

echo "Starting deployment process..."

#ECR Login
echo "Logging into ECR..."
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 878239241975.dkr.ecr.us-east-2.amazonaws.com

# Change to the correct directory
echo "Changing to project directory..."
cd /home/ubuntu/pnut-code/

# Stop existing containers
echo "Stopping existing containers..."
docker compose down


echo "Pulling new images..."
docker compose pull

# Start containers using the latest images
echo "Starting containers with latest images..."
docker compose up -d

# Clean up unused images
echo "Cleaning up unused images & containers..."
docker image prune -f
docker container prune -f

echo "Deployment completed!"