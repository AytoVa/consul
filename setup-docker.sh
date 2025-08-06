#!/bin/bash

# Rails 5.0.7.2 Docker Setup Script
# This script handles the complete first-time setup

set -e

echo "Setting up Consul Rails 5.0.7.2 Docker environment..."

# Stop any existing containers
echo "Stopping any existing containers..."
docker compose down

# Build the images
echo "Building Docker images..."
docker compose build

# Start database service first
echo "Starting database service..."
docker compose up -d database

# Wait for database to be ready
echo "Waiting for database to be ready..."
sleep 10

# Setup database
echo "Setting up database..."
docker compose run --rm app bundle exec rake db:create
docker compose run --rm app bundle exec rake db:migrate
docker compose run --rm app bundle exec rake db:seed

# Start all services
echo "Starting all services..."
docker compose up

echo "Setup complete! Application should be available at http://localhost:3000"
