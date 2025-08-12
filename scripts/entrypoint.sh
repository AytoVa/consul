#!/bin/bash
set -e

# Rails 5.0.7.2 Docker Entrypoint Script
# Optimized for development environment with proper error handling

echo "Starting Consul Rails 5.0.7.2 application..."

# Set default environment
export RAILS_ENV=${RAILS_ENV:-development}
export BUNDLE_PATH=${BUNDLE_PATH:-/usr/local/bundle}

# Function to wait for database
wait_for_db() {
  echo "Waiting for PostgreSQL to be ready..."
  until pg_isready -h "${POSTGRES_HOST:-database}" -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-postgres}" -q; do
    echo "PostgreSQL is unavailable - sleeping"
    sleep 2
  done
  echo "PostgreSQL is ready!"
}

# Function to ensure bundle is properly installed
ensure_bundle() {
  echo "Ensuring bundle dependencies are properly installed..."

  # Fix git ownership issues for bundler git sources (Windows Docker compatibility)
  git config --global --add safe.directory '*'
  git config --global --add safe.directory /var/www/consul

  # Additional fix for Windows Docker Desktop volume mounting
  if [ -d /var/www/consul/.git ]; then
    chown -R consul:consul /var/www/consul/.git 2>/dev/null || true
  fi

  bundle install --jobs 4 --retry 3
}

# Function to setup database
setup_database() {
  echo "Setting up database..."

  # Copy database configuration if it doesn't exist
  if [ ! -f config/database.yml ]; then
    echo "📋 Copying database configuration..."
    cp config/database-docker.yml.example config/database.yml
  fi

  # Copy secrets configuration if it doesn't exist
  if [ ! -f config/secrets.yml ]; then
    echo "Copying secrets configuration..."
    cp config/secrets.yml.example config/secrets.yml
  fi

  # Create database if it doesn't exist
  if ! bundle exec rake db:version > /dev/null 2>&1; then
    echo "Creating database..."
    bundle exec rake db:create
    bundle exec rake db:migrate

    # Seed database in development
    if [ "$RAILS_ENV" = "development" ]; then
      echo "Seeding database..."
      bundle exec rake db:seed
    fi
  else
    echo "Running database migrations..."
    bundle exec rake db:migrate
  fi
}

# Function to handle user permissions (for development)
setup_permissions() {
  if [ -f /var/www/consul/Gemfile ]; then
    USER_UID=$(stat -c %u /var/www/consul/Gemfile)
    USER_GID=$(stat -c %g /var/www/consul/Gemfile)

    export USER_UID
    export USER_GID

    # Update consul user to match host user
    usermod -u "$USER_UID" consul 2> /dev/null || true
    groupmod -g "$USER_GID" consul 2> /dev/null || true
    usermod -g "$USER_GID" consul 2> /dev/null || true

    # Fix bundle permissions
    if [ -d "$BUNDLE_PATH" ]; then
      chown -R "$USER_UID:$USER_GID" "$BUNDLE_PATH" 2> /dev/null || true
    fi

    # Create and fix log directory permissions
    mkdir -p /var/www/consul/log
    touch /var/www/consul/log/development.log
    touch /var/www/consul/log/delayed_job.log
    chown -R "$USER_UID:$USER_GID" /var/www/consul/log 2> /dev/null || true
    chmod -R 0664 /var/www/consul/log/*.log 2> /dev/null || true

    # Fix application permissions
    chown -R "$USER_UID:$USER_GID" /var/www/consul/tmp 2> /dev/null || true
  fi
}

# Function to precompile assets if needed
setup_assets() {
  if [ "$RAILS_ENV" = "production" ] || [ "$PRECOMPILE_ASSETS" = "true" ]; then
    echo "🎨 Precompiling assets..."
    bundle exec rake assets:precompile
  fi
}

# Main execution
main() {
  # Fix git ownership issues immediately (Windows Docker compatibility)
  git config --global --add safe.directory '*'
  git config --global --add safe.directory /var/www/consul

  # Create log files early (Windows Docker compatibility)
  mkdir -p /var/www/consul/log
  touch /var/www/consul/log/development.log
  touch /var/www/consul/log/delayed_job.log
  chmod 0666 /var/www/consul/log/*.log 2> /dev/null || true

  # Wait for database to be ready
  wait_for_db

  # Setup permissions for development
  if [ "$RAILS_ENV" = "development" ]; then
    setup_permissions
  fi

  # Ensure bundle dependencies are properly installed
  ensure_bundle

  # Setup database
  setup_database

  # Setup assets if needed
  setup_assets

  # Remove any existing server PID file
  if [ -f tmp/pids/server.pid ]; then
    echo "Removing existing server PID file..."
    rm tmp/pids/server.pid
  fi

  echo "Consul application is ready!"

  # Execute the main command
  if [ "$RAILS_ENV" = "development" ] && [ -f /var/www/consul/Gemfile ]; then
    # Run as consul user in development
    exec /usr/bin/sudo -EH -u consul "$@"
  else
    # Run directly in production
    exec "$@"
  fi
}

# Run main function
main "$@"

