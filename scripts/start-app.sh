#!/bin/bash
set -e

echo "...Starting Consul Rails application..."

# Fix git ownership issues
git config --global --add safe.directory /var/www/consul

# Change to application directory
cd /var/www/consul

# Create necessary directories for Puma
mkdir -p tmp/pids tmp/sockets log

# Remove any existing server PID file
if [ -f tmp/pids/server.pid ]; then
  echo "Removing existing server PID file..."
  rm tmp/pids/server.pid
fi

# Start Puma in the foreground
echo "Starting Puma server..."
bundle exec puma -C config/puma.rb
