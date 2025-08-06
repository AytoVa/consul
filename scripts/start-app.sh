#!/bin/bash
set -e

echo "...Starting Consul Rails application..."

# Fix git ownership issues
git config --global --add safe.directory /var/www/consul

# Change to application directory
cd /var/www/consul

# Create necessary directories for Puma
mkdir -p tmp/pids tmp/sockets log

# Start Puma in the foreground
bundle exec puma -C config/puma.rb
