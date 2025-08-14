#!/bin/bash
# Don't exit on errors initially
set +e

# Rails 5.0.7.2 Docker Entrypoint Script
# Optimized for development environment with proper error handling

echo "Starting Consul Rails 5.0.7.2 application..."

# Set default environment
export RAILS_ENV=${RAILS_ENV:-development}
export BUNDLE_PATH=${BUNDLE_PATH:-/usr/local/bundle}

# Function to fix git ownership issues comprehensively
fix_git_ownership() {
  echo "Fixing git ownership issues for Docker volume mounting..."

  # Set git config for root user first
  git config --global --add safe.directory '*'
  git config --global --add safe.directory /var/www/consul

  # If we have a Gemfile, get the host user ID and fix ownership
  if [ -f /var/www/consul/Gemfile ]; then
    HOST_UID=$(stat -c %u /var/www/consul/Gemfile 2>/dev/null || echo "1000")
    HOST_GID=$(stat -c %g /var/www/consul/Gemfile 2>/dev/null || echo "1000")

    echo "Host user ID: $HOST_UID, Group ID: $HOST_GID"

    # Fix ownership of the entire application directory
    echo "Setting ownership of application directory..."
    chown -R "$HOST_UID:$HOST_GID" /var/www/consul 2>/dev/null || true

    # Update consul user to match host user
    echo "Updating consul user to match host user..."
    usermod -u "$HOST_UID" consul 2>/dev/null || true
    groupmod -g "$HOST_GID" consul 2>/dev/null || true
    usermod -g "$HOST_GID" consul 2>/dev/null || true

    # Set git config for consul user as well
    sudo -u consul git config --global --add safe.directory '*' 2>/dev/null || true
    sudo -u consul git config --global --add safe.directory /var/www/consul 2>/dev/null || true
  fi

  echo "Git ownership issues fixed."
}

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

  # Check bundler version
  echo "Current bundler version:"
  bundler --version

  # Ensure we use the exact bundler version from Gemfile.lock (2.1.4)
  echo "Installing bundler 2.1.4 to match Gemfile.lock..."
  gem install bundler -v 2.1.4

  # Set bundle config to avoid permission issues
  echo "Configuring bundle for consul user..."
  sudo -u consul bundle config set --local path "$BUNDLE_PATH"
  if [ "$RAILS_ENV" = "production" ]; then
    sudo -u consul bundle config set --local without 'development test'
  fi

  # Run bundle install as consul user to avoid permission issues
  echo "Running bundle install..."
  sudo -u consul bundle install --jobs 4 --retry 3
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

# Function to handle additional permissions (for development in windows)
setup_permissions() {
  echo "Setting up additional permissions..."

  # Fix bundle permissions and create bundle config directory
  if [ -d "$BUNDLE_PATH" ]; then
    echo "Fixing bundle permissions..."
    chown -R consul:consul "$BUNDLE_PATH" 2>/dev/null || true
  fi

  # Create and fix bundle config directory permissions
  echo "Setting up bundle config directory..."
  mkdir -p /var/www/consul/.bundle
  chown -R consul:consul /var/www/consul/.bundle 2>/dev/null || true
  chmod -R 755 /var/www/consul/.bundle 2>/dev/null || true

  # Create and fix log directory permissions
  mkdir -p /var/www/consul/log
  touch /var/www/consul/log/development.log
  touch /var/www/consul/log/delayed_job.log
  chown -R consul:consul /var/www/consul/log 2>/dev/null || true
  chmod -R 0664 /var/www/consul/log/*.log 2>/dev/null || true

  # Fix application permissions
  chown -R consul:consul /var/www/consul/tmp 2>/dev/null || true

  echo "Additional permissions setup completed."
}

# Function to precompile assets if needed
setup_assets() {
  if [ "$RAILS_ENV" = "production" ] || [ "$PRECOMPILE_ASSETS" = "true" ]; then
    echo "Precompiling assets for production..."
    sudo -u consul bundle exec rake assets:precompile
  elif [ "$RAILS_ENV" = "development" ]; then
    echo "Setting up assets for development..."
    # Clean and precompile assets
    sudo -u consul bundle exec rake assets:clobber assets:precompile
  fi
}

# Function to setup Puma directories and clean PID files (Windows Docker compatibility)
setup_puma_directories() {
  echo "Setting up Puma directories and cleaning PID files..."

  # Create required directories for Puma
  mkdir -p /var/www/consul/tmp/pids
  mkdir -p /var/www/consul/tmp/sockets
  mkdir -p /var/www/consul/log

  # Remove any existing Puma-related files that might cause conflicts
  if [ -f /var/www/consul/tmp/pids/server.pid ]; then
    echo "Removing existing server PID file..."
    rm -f /var/www/consul/tmp/pids/server.pid
  fi

  if [ -f /var/www/consul/tmp/pids/puma.pid ]; then
    echo "Removing existing Puma PID file..."
    rm -f /var/www/consul/tmp/pids/puma.pid
  fi

  if [ -f /var/www/consul/tmp/pids/puma.state ]; then
    echo "Removing existing Puma state file..."
    rm -f /var/www/consul/tmp/pids/puma.state
  fi

  if [ -f /var/www/consul/tmp/sockets/pumactl.sock ]; then
    echo "Removing existing Puma control socket..."
    rm -f /var/www/consul/tmp/sockets/pumactl.sock
  fi

  # Set proper permissions for consul user
  chown -R consul:consul /var/www/consul/tmp 2>/dev/null || true
  chown -R consul:consul /var/www/consul/log 2>/dev/null || true

  # Ensure directories are writable
  chmod -R 755 /var/www/consul/tmp 2>/dev/null || true
  chmod -R 755 /var/www/consul/log 2>/dev/null || true

  echo "Puma directories setup completed."
}

# Main execution
main() {
  # Fix git ownership issues first (critical for Docker volume mounting)
  fix_git_ownership

  # Create log files early (Windows Docker compatibility)
  mkdir -p /var/www/consul/log
  touch /var/www/consul/log/development.log
  touch /var/www/consul/log/delayed_job.log
  chmod 0666 /var/www/consul/log/*.log 2> /dev/null || true

  # Wait for database to be ready
  wait_for_db

  # Setup additional permissions for development
  if [ "$RAILS_ENV" = "development" ]; then
    setup_permissions
  fi

  # Ensure bundle dependencies are properly installed
  ensure_bundle

  # Setup database only if not skipped
  if [ "$SKIP_DATABASE_SETUP" != "true" ]; then
    setup_database
  fi

  # Setup assets if needed
  setup_assets

  # Setup Puma directories and clean PID files (after permission setup)
  setup_puma_directories

  echo "Consul application is ready!"
  echo "Application should be accessible at:"
  echo "  - Root: http://localhost:3000/ (redirects)"
  echo "  - App:  http://localhost:3000/presupuestosparticipativos"

  # Execute the main command
  echo "Starting application with command: $@"
  if [ "$RAILS_ENV" = "development" ] && [ -f /var/www/consul/Gemfile ]; then
    # Run as consul user in development
    echo "Running as consul user..."
    exec /usr/bin/sudo -EH -u consul "$@"
  else
    # Run directly in production
    echo "Running as root user..."
    exec "$@"
  fi
}

# Run main function
main "$@"

